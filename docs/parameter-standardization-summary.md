# Parameter Standardization Summary

## Overview

This document summarizes the standardization of command-line parameters across all scripts in the Azure WebApp Demo project. All scripts now consistently use `--env` instead of the longer `--environment` parameter.

## Changes Made

### Scripts Updated

#### 1. `scripts/cleanup.sh`
**Before:**
```bash
./scripts/cleanup.sh --environment dev --force
```

**After:**
```bash
./scripts/cleanup.sh --env dev --force
```

**Changes:**
- Parameter parsing: `--environment` → `--env`
- Help text updated
- Usage examples updated

#### 2. `scripts/deploy-github.sh`
**Before:**
```bash
./scripts/deploy-github.sh --environment staging --cleanup-hours 4
```

**After:**
```bash
./scripts/deploy-github.sh --env staging --cleanup-hours 4
```

**Changes:**
- Parameter parsing: `--environment` → `--env`
- Help text updated
- Usage examples updated

#### 3. `scripts/cost-monitor.sh`
**Before:**
```bash
# No --env parameter support
```

**After:**
```bash
./scripts/cost-monitor.sh --actual --env demo --export report.json
```

**Changes:**
- Added `--env` parameter support
- Updated help text
- Updated usage examples

### GitHub Actions Workflow Updated

#### `.github/workflows/cleanup.yml`
**Before:**
```bash
./scripts/cleanup.sh --environment "$ENVIRONMENT" --force --verbose
```

**After:**
```bash
./scripts/cleanup.sh --env "$ENVIRONMENT" --force --verbose
```

### Documentation Updated

#### Files Updated:
1. **README.md**
   - Updated deployment examples
   - Changed `--environment` to `--env` in command examples

2. **docs/github-actions-deployment.md**
   - Updated command line deployment examples
   - Consistent parameter usage throughout

3. **docs/environment-protection.md**
   - Updated cleanup command examples
   - Consistent parameter naming

4. **All script help text and usage examples**
   - Standardized parameter documentation
   - Updated examples and descriptions

## Benefits

### 1. Consistency
- All scripts now use the same parameter naming convention
- Reduced cognitive load for users
- Easier to remember and type

### 2. User Experience
- Shorter parameter names (`--env` vs `--environment`)
- Faster command line usage
- Less typing required

### 3. Maintenance
- Consistent codebase
- Easier documentation maintenance
- Reduced confusion in support scenarios

### 4. Developer Experience
- Clear, consistent API across all scripts
- Predictable parameter naming
- Better script composability

## Usage Examples

### Cleanup Operations
```bash
# Dev environment cleanup
./scripts/cleanup.sh --env dev --force

# Staging environment cleanup
./scripts/cleanup.sh --env staging --force

# Production environment cleanup
./scripts/cleanup.sh --env prod --force
```

### Deployment Operations
```bash
# Deploy to staging with custom settings
./scripts/deploy-github.sh --env staging --cleanup-hours 4 --budget 50

# Deploy to production
./scripts/deploy-github.sh --env prod --no-cleanup --budget 100
```

### Cost Monitoring
```bash
# Monitor costs for specific environment
./scripts/cost-monitor.sh --actual --env dev

# Export cost report for environment
./scripts/cost-monitor.sh --actual --env staging --export staging-costs.json
```

## Migration Guide

### For Existing Users
If you have existing scripts or documentation that use `--environment`, update them to use `--env`:

**Old commands:**
```bash
./scripts/cleanup.sh --environment dev
./scripts/deploy-github.sh --environment staging
```

**New commands:**
```bash
./scripts/cleanup.sh --env dev
./scripts/deploy-github.sh --env staging
```

### Backward Compatibility
**Note:** The old `--environment` parameter is no longer supported. All scripts have been updated to use `--env` exclusively.

## Testing

### Verification Steps
1. **Script Syntax**: All scripts pass syntax validation
2. **Parameter Parsing**: All scripts correctly parse `--env` parameter
3. **Help Text**: All help text displays correct parameter information
4. **GitHub Actions**: Cleanup workflow uses correct parameter format
5. **Documentation**: All documentation examples use consistent parameters

### Test Commands
```bash
# Test script help text
./scripts/cleanup.sh --help
./scripts/deploy-github.sh --help
./scripts/cost-monitor.sh --help

# Test parameter parsing
./scripts/cleanup.sh --env dev --help
./scripts/deploy-github.sh --env staging --help
./scripts/cost-monitor.sh --env demo --help
```

## Related Issues Resolved

1. **GitHub Actions Cleanup Failure**: Fixed "Unknown option: --env" error
2. **Documentation Inconsistency**: Standardized all parameter references
3. **User Confusion**: Eliminated mixed parameter naming
4. **Script Interoperability**: Improved script-to-script calling consistency

## Future Considerations

1. **New Scripts**: All new scripts should use `--env` parameter for environment specification
2. **Documentation**: All new documentation should use consistent parameter naming
3. **Examples**: All code examples should demonstrate the standardized parameters
4. **Testing**: Include parameter consistency checks in automated testing

This standardization improves the overall user experience and maintainability of the Azure WebApp Demo project.
