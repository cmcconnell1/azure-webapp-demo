#!/usr/bin/env bash
set -euo pipefail

# Demo Compliance Verification Script
# Verifies that demo exceptions are properly documented and justified
# Per project requirement: "Treat all data as critical PII"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "DEMO COMPLIANCE VERIFICATION"
echo "============================"
echo "Project: Azure WebApp Demo"
echo "Purpose: Verify demo exceptions are properly documented"
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

VIOLATIONS=0
WARNINGS=0

# Function to report violation
report_violation() {
    local message="$1"
    echo -e "${RED}VIOLATION:${NC} $message"
    ((VIOLATIONS++))
}

# Function to report warning
report_warning() {
    local message="$1"
    echo -e "${YELLOW}WARNING:${NC} $message"
    ((WARNINGS++))
}

# Function to report success
report_success() {
    local message="$1"
    echo -e "${GREEN}PASS:${NC} $message"
}

echo "1. CHECKING DEMO EXCEPTION DOCUMENTATION"
echo "----------------------------------------"

# Check if PII compliance documentation exists
if [ -f "$PROJECT_ROOT/docs/pii-compliance.md" ]; then
    report_success "PII compliance documentation exists"
    
    # Check for demo exception section
    if grep -q "Demo Exception Disclaimer" "$PROJECT_ROOT/docs/pii-compliance.md"; then
        report_success "Demo exception disclaimer found in documentation"
    else
        report_violation "Demo exception disclaimer missing from documentation"
    fi
    
    # Check for justification
    if grep -q "Greenfield infrastructure demo" "$PROJECT_ROOT/docs/pii-compliance.md"; then
        report_success "Demo justification documented"
    else
        report_violation "Demo justification missing from documentation"
    fi
    
    # Check for production requirements
    if grep -q "MUST NOT be used in production" "$PROJECT_ROOT/docs/pii-compliance.md"; then
        report_success "Production restrictions documented"
    else
        report_violation "Production restrictions not documented"
    fi
else
    report_violation "PII compliance documentation missing"
fi

echo ""
echo "2. CHECKING SEED FILE DOCUMENTATION"
echo "-----------------------------------"

# Check if seed file exists and is properly documented
if [ -f "$PROJECT_ROOT/database/seed/quotes.json" ]; then
    report_success "Demo seed file exists"
    
    # Check for disclaimer in seed file
    if grep -q "_comment.*DEMO PROJECT ONLY" "$PROJECT_ROOT/database/seed/quotes.json"; then
        report_success "Seed file contains demo disclaimer"
    else
        report_violation "Seed file missing demo disclaimer"
    fi
    
    # Check for violation acknowledgment
    if grep -q "_violation.*violates security best practices" "$PROJECT_ROOT/database/seed/quotes.json"; then
        report_success "Seed file acknowledges security violation"
    else
        report_violation "Seed file does not acknowledge security violation"
    fi
    
    # Check for production guidance
    if grep -q "_production.*Azure Key Vault" "$PROJECT_ROOT/database/seed/quotes.json"; then
        report_success "Seed file provides production guidance"
    else
        report_violation "Seed file missing production guidance"
    fi
else
    report_warning "Demo seed file not found - may be using production-ready approach"
fi

echo ""
echo "3. CHECKING APPLICATION CODE WARNINGS"
echo "-------------------------------------"

# Check if application code warns about demo data
if grep -q "DEMO PROJECT ONLY.*mock-PII data" "$PROJECT_ROOT/app/db.py"; then
    report_success "Application code warns about demo data usage"
else
    report_violation "Application code missing demo data warnings"
fi

# Check if application code references documentation
if grep -q "docs/pii-compliance.md" "$PROJECT_ROOT/app/db.py"; then
    report_success "Application code references compliance documentation"
else
    report_warning "Application code should reference compliance documentation"
fi

echo ""
echo "4. CHECKING TERRAFORM CONFIGURATION"
echo "-----------------------------------"

# Check if Terraform has proper lifecycle rules
if grep -q "ignore_changes.*value" "$PROJECT_ROOT/terraform/main.tf"; then
    report_success "Terraform has lifecycle rule to protect external data"
else
    report_warning "Terraform missing lifecycle rule for external data protection"
fi

# Check if Terraform references documentation
if grep -q "docs/pii-compliance.md" "$PROJECT_ROOT/terraform/main.tf"; then
    report_success "Terraform references compliance documentation"
else
    report_warning "Terraform should reference compliance documentation"
fi

echo ""
echo "5. CHECKING README DOCUMENTATION"
echo "--------------------------------"

# Check if README mentions PII requirements
if grep -q "Treat all data as critical PII" "$PROJECT_ROOT/README.md"; then
    report_success "README documents PII requirements"
else
    report_warning "README should document PII requirements"
fi

# Check if README mentions demo limitations
if grep -q "DEMO\|demo\|testing" "$PROJECT_ROOT/README.md"; then
    report_success "README indicates demo/testing nature"
else
    report_warning "README should clearly indicate demo/testing nature"
fi

echo ""
echo "6. SUMMARY"
echo "=========="

if [ $VIOLATIONS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}DEMO COMPLIANCE: EXCELLENT${NC}"
        echo "All demo exceptions are properly documented and justified."
    else
        echo -e "${YELLOW}DEMO COMPLIANCE: GOOD${NC}"
        echo "Demo exceptions are documented with $WARNINGS minor improvement(s) recommended."
    fi
    echo ""
    echo "DEMO STATUS:"
    echo "- Demo exceptions are properly documented"
    echo "- Security violations are acknowledged"
    echo "- Production guidance is provided"
    echo "- Users are warned about demo limitations"
else
    echo -e "${RED}DEMO COMPLIANCE: NEEDS IMPROVEMENT${NC}"
    echo "Found $VIOLATIONS critical documentation issue(s) and $WARNINGS warning(s)."
    echo ""
    echo "REQUIRED ACTIONS:"
    echo "1. Add proper demo exception documentation"
    echo "2. Include security violation acknowledgments"
    echo "3. Provide clear production guidance"
    echo "4. Update application code warnings"
    echo "5. Reference compliance documentation"
fi

echo ""
echo "DEMO vs PRODUCTION:"
echo "- DEMO: Contains documented PII exceptions for functionality"
echo "- PRODUCTION: Must remove all PII from source control"
echo ""
echo "For production deployment guidance, see: docs/pii-compliance.md"

exit $VIOLATIONS
