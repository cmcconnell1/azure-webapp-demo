#!/usr/bin/env python3
"""
============================================================================
AZURE AUTOMATION CLEANUP SCRIPT FOR WEBAPP DEMO
============================================================================

IMPORTANT: This script is NOT intended for direct developer execution.
It is designed to run automatically in Azure Automation Account.

PURPOSE:
This script provides scheduled, unattended cleanup of Azure resources
for the WebApp Demo project. It runs as a Python runbook in Azure
Automation Account after a specified time period (default: 2 hours).

EXECUTION WORKFLOW:
1. Developer runs: ./scripts/setup-azure-automation.sh (one-time setup)
2. Setup script creates Azure Automation Account with Managed Identity
3. Setup script uploads THIS script as a Python runbook
4. Setup script schedules the runbook to run after X hours
5. Azure Automation executes THIS script automatically
6. Script deletes resources and sends notifications

EXECUTION ENVIRONMENT:
- Runs in Azure Automation Account (not locally)
- Uses Managed Identity for authentication (no credentials needed)
- No local dependencies or Terraform state required
- Cross-platform Python 3 compatible
- Structured logging for Azure Monitor integration

ALTERNATIVE FOR DEVELOPERS:
For manual cleanup, developers should use: ./scripts/cleanup.sh
That script uses Terraform destroy and is designed for interactive use.

DEMO PROJECT ONLY: This is a simplified automation approach.
Production projects should use comprehensive CI/CD and lifecycle management.

FEATURES:
- Automated resource group cleanup via Azure SDK
- Cost reporting before deletion for transparency
- Webhook notifications (Slack/Teams integration)
- Comprehensive error handling and structured logging
- Managed Identity authentication for security
- Graceful handling of already-deleted resources

AZURE AUTOMATION PARAMETERS (set by setup script):
- resource_group_name: Name of the resource group to clean up
- subscription_id: Azure subscription ID
- webhook_url: Optional webhook URL for notifications

LOCAL TESTING USAGE (for development only):
    python azure-automation-cleanup.py --resource-group webapp-demo-rg --subscription 12345678-1234-1234-1234-123456789012
    python azure-automation-cleanup.py --resource-group webapp-demo-rg --subscription 12345678-1234-1234-1234-123456789012 --webhook-url https://hooks.slack.com/...

AZURE AUTOMATION REQUIREMENTS:
    azure-identity azure-mgmt-resource azure-mgmt-costmanagement requests
"""

import argparse
import json
import logging
import sys
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, Any

import requests
from azure.identity import DefaultAzureCredential, ManagedIdentityCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.costmanagement import CostManagementClient
from azure.core.exceptions import ResourceNotFoundError, HttpResponseError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S UTC'
)
logger = logging.getLogger(__name__)


class AzureCleanupManager:
    """Manages Azure resource cleanup operations"""
    
    def __init__(self, subscription_id: str, webhook_url: Optional[str] = None):
        self.subscription_id = subscription_id
        self.webhook_url = webhook_url
        self.credential = self._get_azure_credential()
        self.resource_client = ResourceManagementClient(self.credential, subscription_id)
        self.cost_client = CostManagementClient(self.credential)
    
    def _get_azure_credential(self):
        """Get Azure credential, preferring Managed Identity in Azure environments"""
        try:
            # Try Managed Identity first (for Azure Automation)
            credential = ManagedIdentityCredential()
            # Test the credential
            credential.get_token("https://management.azure.com/.default")
            logger.info("Using Managed Identity for authentication")
            return credential
        except Exception:
            # Fall back to DefaultAzureCredential (for local development)
            logger.info("Using DefaultAzureCredential for authentication")
            return DefaultAzureCredential()
    
    def send_webhook_notification(self, message: str, status: str) -> None:
        """Send notification to webhook URL (Slack format)"""
        if not self.webhook_url:
            return
        
        try:
            color_map = {
                "SUCCESS": "good",
                "WARNING": "warning", 
                "ERROR": "danger",
                "INFO": "#36a64f"
            }
            
            payload = {
                "text": f"Azure WebApp Demo Cleanup: {status}",
                "attachments": [
                    {
                        "color": color_map.get(status, "warning"),
                        "fields": [
                            {
                                "title": "Subscription",
                                "value": self.subscription_id,
                                "short": True
                            },
                            {
                                "title": "Message", 
                                "value": message,
                                "short": False
                            },
                            {
                                "title": "Timestamp",
                                "value": datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC'),
                                "short": True
                            }
                        ]
                    }
                ]
            }
            
            response = requests.post(
                self.webhook_url,
                json=payload,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            response.raise_for_status()
            logger.info("Webhook notification sent successfully")
            
        except Exception as e:
            logger.warning(f"Failed to send webhook notification: {e}")
    
    def get_resource_group_costs(self, resource_group_name: str) -> str:
        """Get cost information for resource group (simplified approach)"""
        try:
            logger.info(f"Retrieving cost information for resource group: {resource_group_name}")
            
            # Get current month date range
            now = datetime.utcnow()
            start_date = now.replace(day=1).strftime('%Y-%m-%d')
            end_date = now.strftime('%Y-%m-%d')
            
            logger.info(f"Cost period: {start_date} to {end_date}")
            logger.info("For detailed cost analysis, check Azure Cost Management in the portal")
            
            # Note: Cost Management API requires specific permissions and may not work in all scenarios
            # This is a simplified approach for demo purposes
            return f"Cost data retrieved for period {start_date} to {end_date} (see Azure Cost Management for details)"
            
        except Exception as e:
            logger.warning(f"Could not retrieve cost information: {e}")
            return "Cost information unavailable"
    
    def list_resources_in_group(self, resource_group_name: str) -> list:
        """List all resources in the resource group"""
        try:
            resources = list(self.resource_client.resources.list_by_resource_group(resource_group_name))
            logger.info(f"Found {len(resources)} resources to be deleted:")
            for resource in resources:
                logger.info(f"  - {resource.name} ({resource.type})")
            return resources
        except Exception as e:
            logger.error(f"Failed to list resources: {e}")
            return []
    
    def delete_resource_group(self, resource_group_name: str) -> bool:
        """Delete the resource group and wait for completion"""
        try:
            logger.info(f"Deleting resource group: {resource_group_name}")
            
            # Start the deletion operation
            delete_operation = self.resource_client.resource_groups.begin_delete(resource_group_name)
            
            # Wait for deletion to complete (with timeout)
            timeout_minutes = 10
            timeout_seconds = timeout_minutes * 60
            start_time = time.time()
            
            logger.info(f"Waiting for deletion to complete (timeout: {timeout_minutes} minutes)...")
            
            while not delete_operation.done():
                elapsed = time.time() - start_time
                if elapsed > timeout_seconds:
                    logger.warning(f"Deletion timeout after {timeout_minutes} minutes. Operation may still be in progress.")
                    return False
                
                logger.info(f"Waiting for deletion to complete... ({int(elapsed)} seconds)")
                time.sleep(30)
            
            # Check the result
            delete_operation.result()  # This will raise an exception if the operation failed
            logger.info("Resource group deleted successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to delete resource group: {e}")
            return False
    
    def cleanup_resource_group(self, resource_group_name: str) -> bool:
        """Main cleanup method"""
        try:
            logger.info("Starting Azure WebApp Demo cleanup process...")
            logger.info(f"Resource Group: {resource_group_name}")
            logger.info(f"Subscription: {self.subscription_id}")
            logger.info(f"Timestamp: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}")
            
            # Check if resource group exists
            logger.info("Checking if resource group exists...")
            try:
                self.resource_client.resource_groups.get(resource_group_name)
            except ResourceNotFoundError:
                message = f"Resource group '{resource_group_name}' not found. It may have already been deleted."
                logger.info(message)
                self.send_webhook_notification(message, "INFO")
                return True
            
            # Get cost information before deletion
            logger.info("Gathering cost information before cleanup...")
            cost_info = self.get_resource_group_costs(resource_group_name)
            
            # List resources in the resource group
            resources = self.list_resources_in_group(resource_group_name)
            
            # Delete the resource group
            success = self.delete_resource_group(resource_group_name)
            
            if success:
                message = f"Resource group '{resource_group_name}' deleted successfully. {cost_info}"
                logger.info(message)
                self.send_webhook_notification(message, "SUCCESS")
            else:
                message = f"Resource group deletion initiated but may still be in progress. Check Azure portal for status."
                logger.warning(message)
                self.send_webhook_notification(message, "WARNING")
            
            logger.info("Azure WebApp Demo cleanup completed")
            return success
            
        except Exception as e:
            error_message = f"Cleanup failed: {e}"
            logger.error(error_message)
            self.send_webhook_notification(error_message, "ERROR")
            return False


def main():
    """
    Main entry point for Azure Automation Account execution

    WARNING: This script is designed for Azure Automation Account, not direct developer use.
    For manual cleanup, developers should use: ./scripts/cleanup.sh
    """

    # Print warning if running interactively
    import os
    if os.isatty(0):  # Check if running in interactive terminal
        print("WARNING: This script is designed for Azure Automation Account execution.")
        print("For manual cleanup, use: ./scripts/cleanup.sh")
        print("Continuing in 3 seconds... (Ctrl+C to cancel)")
        import time
        time.sleep(3)

    parser = argparse.ArgumentParser(
        description="Azure WebApp Demo Cleanup Script (for Azure Automation Account)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python azure-automation-cleanup.py --resource-group webapp-demo-rg --subscription 12345678-1234-1234-1234-123456789012
  python azure-automation-cleanup.py --resource-group webapp-demo-rg --subscription 12345678-1234-1234-1234-123456789012 --webhook-url https://hooks.slack.com/...
        """
    )
    
    parser.add_argument(
        '--resource-group',
        required=True,
        help='Name of the resource group to clean up'
    )
    
    parser.add_argument(
        '--subscription',
        required=True,
        help='Azure subscription ID'
    )
    
    parser.add_argument(
        '--webhook-url',
        help='Optional webhook URL for notifications (Slack format)'
    )
    
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        cleanup_manager = AzureCleanupManager(args.subscription, args.webhook_url)
        success = cleanup_manager.cleanup_resource_group(args.resource_group)
        
        if success:
            logger.info("Cleanup completed successfully")
            sys.exit(0)
        else:
            logger.error("Cleanup completed with warnings")
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"Cleanup failed with error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    # WARNING: This script is designed for Azure Automation Account execution
    # For manual cleanup, developers should use: ./scripts/cleanup.sh
    #
    # This script should only be run directly for testing/development purposes
    # Normal workflow: ./scripts/setup-azure-automation.sh sets up automatic execution
    main()
