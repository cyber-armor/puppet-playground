# Puppet r10k Testbed Guide: Windows Defender CIS Controls

## Executive Summary

This guide provides a complete framework for building a Puppet r10k testbed focused on managing Windows Defender settings per CIS benchmarks. It includes repository structure, scaling patterns, and a working proof-of-concept.

## Table of Contents

1. [Overview](#overview)
2. [r10k Fundamentals](#r10k-fundamentals)
3. [Repository Structure](#repository-structure)
4. [Environment Setup](#environment-setup)
5. [Windows Defender CIS Controls](#windows-defender-cis-controls)
6. [Scaling Strategy](#scaling-strategy)
7. [Testing Workflow](#testing-workflow)
8. [Best Practices](#best-practices)

---

## Overview

### Architecture Components

```
┌─────────────────┐
│  Control Repo   │ ← Git repository (your code)
│  (GitHub/GitLab)│
└────────┬────────┘
         │
         ├─ r10k pulls code
         ↓
┌─────────────────┐
│  Puppet Server  │ ← Manages environments
│  (Helm Chart)   │
└────────┬────────┘
         │
         ├─ Puppet agent pulls catalog
         ↓
┌─────────────────┐
│ Windows Agents  │ ← Applies configuration
│ (CIS Controls)  │
└─────────────────┘
```

### Objectives

- **Immediate**: Prove r10k + Puppet can control Windows Defender CIS settings
- **Short-term**: Establish scalable repository patterns
- **Long-term**: Expand to comprehensive Windows endpoint management

---

## r10k Fundamentals

### What is r10k?

r10k is Puppet's code deployment tool that:
- Maps Git branches to Puppet environments
- Manages module dependencies via Puppetfile
- Enables GitOps workflow for infrastructure

### How r10k Works

```
Git Branch      →    Puppet Environment    →    Agent Access
-----------          -------------------        -------------
production      →    /etc/puppetlabs/code/environments/production
development     →    /etc/puppetlabs/code/environments/development
feature/win-av  →    /etc/puppetlabs/code/environments/feature_win-av
```

**Key Concept**: Each Git branch becomes a Puppet environment, allowing isolated testing.

---

## Repository Structure

### Control Repository Layout

This is the heart of your Puppet infrastructure. Create this structure in your Git repository:

```
puppet-control-repo/
├── Puppetfile                    # Module dependencies
├── environment.conf              # Environment configuration
├── hiera.yaml                    # Data lookup configuration
├── data/                         # Hiera data (hierarchical config)
│   ├── common.yaml              # Global defaults
│   ├── os/
│   │   └── windows.yaml         # Windows-specific settings
│   ├── roles/
│   │   ├── workstation.yaml     # Workstation role settings
│   │   └── server.yaml          # Server role settings
│   └── nodes/
│       └── <certname>.yaml      # Node-specific overrides
├── manifests/
│   └── site.pp                  # Main entry point
└── site-modules/                # Custom modules (your code)
    └── profile/
        ├── manifests/
        │   └── windows/
        │       ├── baseline.pp
        │       └── defender_cis.pp
        └── files/
```

### File Contents

#### `Puppetfile`

This file defines all external module dependencies:

```ruby
# Puppetfile - Module Dependencies
forge 'https://forge.puppet.com'

# Core Windows modules
mod 'puppetlabs-stdlib', '9.6.0'
mod 'puppetlabs-registry', '5.0.1'
mod 'puppetlabs-pwshlib', '1.2.1'

# Windows-specific modules
mod 'puppetlabs-dsc_lite', '4.0.0'
mod 'puppetlabs-chocolatey', '8.1.0'

# Security/compliance
mod 'puppetlabs-audit', '1.0.0'

# Optional: If you want pre-built security profiles
# mod 'puppet-windows_security', :git => 'https://github.com/example/windows_security.git'
```

#### `environment.conf`

```ini
# environment.conf - Environment Settings
modulepath = site-modules:modules:$basemodulepath
environment_timeout = unlimited
```

#### `hiera.yaml`

This configures your hierarchical data lookup:

```yaml
# hiera.yaml - Data Hierarchy
---
version: 5

defaults:
  datadir: data
  data_hash: yaml_data

hierarchy:
  # Node-specific (highest priority)
  - name: "Per-node data"
    path: "nodes/%{trusted.certname}.yaml"
  
  # Role-based
  - name: "Per-role data"
    path: "roles/%{facts.role}.yaml"
  
  # OS-specific
  - name: "Per-OS family"
    path: "os/%{facts.os.family}.yaml"
  
  # Global defaults (lowest priority)
  - name: "Common data"
    path: "common.yaml"
```

#### `manifests/site.pp`

Main entry point for classification:

```puppet
# manifests/site.pp - Node Classification

# Default node definition
node default {
  # Lookup role from facts/hiera
  $role = lookup('role', String, 'first', 'base')
  
  # Include role-based profile
  include "profile::${role}"
  
  # Reporting
  notify { "Applying role: ${role} to ${trusted.certname}": }
}

# Example: Explicit node classification (alternative approach)
# node 'win-workstation-01.example.com' {
#   include profile::windows::workstation
# }
```

---

## Environment Setup

### Prerequisites

1. **Puppet Server** (deployed via official Helm chart)
2. **Git repository** (GitHub, GitLab, or Bitbucket)
3. **r10k configuration** on Puppet Server

### r10k Configuration

On the Puppet Server, configure r10k (this is typically done via Helm values):

```yaml
# values.yaml for Puppet Helm chart
r10k:
  enabled: true
  sources:
    puppet:
      remote: 'https://github.com/your-org/puppet-control-repo.git'
      basedir: '/etc/puppetlabs/code/environments'
      # For private repos:
      # credentials:
      #   ssh:
      #     private_key: |
      #       -----BEGIN RSA PRIVATE KEY-----
      #       ...
      #       -----END RSA PRIVATE KEY-----
  
  # Webhook for automatic deployments (optional)
  webhook:
    enabled: true
    prefix: '/payload'
```

### Deploy r10k Code

```bash
# Manual deployment (on Puppet Server)
r10k deploy environment -pv

# Or via webhook (preferred for automation)
curl -X POST https://puppet-server.example.com:8088/payload
```

---

## Windows Defender CIS Controls

### CIS Benchmark Context

The CIS Microsoft Windows 10/11 Benchmark includes several Windows Defender-related controls. Here are key examples:

| Control ID | Setting | CIS Value | Registry Path |
|------------|---------|-----------|---------------|
| 18.9.15.1 | Turn on behavior monitoring | Enabled | `HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection!DisableBehaviorMonitoring` |
| 18.9.15.2 | Scan all downloaded files | Enabled | `HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection!DisableIOAVProtection` |
| 18.9.15.3 | Turn on script scanning | Enabled | `HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection!DisableScriptScanning` |
| 18.9.15.8 | Configure real-time protection | Enabled | `HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection!DisableRealtimeMonitoring` |

### Hiera Data Structure

#### `data/common.yaml`

```yaml
# data/common.yaml - Global Defaults
---
# Default role if not specified
role: 'base'

# Disable Defender controls by default (opt-in model)
profile::windows::defender_cis::manage_defender: false
```

#### `data/os/windows.yaml`

```yaml
# data/os/windows.yaml - Windows-Specific Settings
---
# Enable Defender management for Windows
profile::windows::defender_cis::manage_defender: true

# CIS Benchmark Settings for Windows Defender
profile::windows::defender_cis::settings:
  
  # 18.9.15.1 - Turn on behavior monitoring (CIS L1)
  behavior_monitoring:
    ensure: 'enabled'
    registry_key: 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
    registry_value: 'DisableBehaviorMonitoring'
    data: 0
    type: 'dword'
    cis_control: '18.9.15.1'
    cis_level: 'L1'
  
  # 18.9.15.2 - Scan downloaded files and attachments (CIS L1)
  scan_downloads:
    ensure: 'enabled'
    registry_key: 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
    registry_value: 'DisableIOAVProtection'
    data: 0
    type: 'dword'
    cis_control: '18.9.15.2'
    cis_level: 'L1'
  
  # 18.9.15.3 - Turn on script scanning (CIS L1)
  script_scanning:
    ensure: 'enabled'
    registry_key: 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
    registry_value: 'DisableScriptScanning'
    data: 0
    type: 'dword'
    cis_control: '18.9.15.3'
    cis_level: 'L1'
  
  # 18.9.15.8 - Configure real-time protection (CIS L1)
  realtime_protection:
    ensure: 'enabled'
    registry_key: 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
    registry_value: 'DisableRealtimeMonitoring'
    data: 0
    type: 'dword'
    cis_control: '18.9.15.8'
    cis_level: 'L1'
  
  # Cloud-delivered protection (Best Practice)
  cloud_protection:
    ensure: 'enabled'
    registry_key: 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'
    registry_value: 'SpynetReporting'
    data: 2
    type: 'dword'
    cis_control: '18.9.15.4'
    cis_level: 'L1'
```

#### `data/roles/workstation.yaml`

```yaml
# data/roles/workstation.yaml - Workstation-Specific Settings
---
role: 'workstation'

# Workstations get full CIS L1 profile
profile::windows::defender_cis::cis_level: 'L1'

# Optional: Override specific settings for workstations
# profile::windows::defender_cis::settings:
#   cloud_protection:
#     data: 1  # Basic instead of Advanced
```

### Profile Implementation

#### `site-modules/profile/manifests/windows/defender_cis.pp`

```puppet
# site-modules/profile/manifests/windows/defender_cis.pp
# Profile for Windows Defender CIS Benchmark Controls

class profile::windows::defender_cis {
  
  # Check if we should manage Defender
  $manage_defender = lookup('profile::windows::defender_cis::manage_defender', Boolean, 'first', true)
  
  unless $manage_defender {
    notify { 'Windows Defender CIS controls disabled for this node': }
    return()
  }
  
  # Get CIS level (L1 or L2)
  $cis_level = lookup('profile::windows::defender_cis::cis_level', String, 'first', 'L1')
  
  # Retrieve all Defender settings from Hiera
  $all_settings = lookup('profile::windows::defender_cis::settings', Hash, 'deep', {})
  
  # Filter settings based on CIS level
  $settings = $all_settings.filter |$key, $value| {
    $value['cis_level'] == $cis_level or $value['cis_level'] == 'L1'
  }
  
  # Report what we're doing
  notify { "Applying CIS ${cis_level} Windows Defender controls":
    message => "Configuring ${settings.length} Defender settings per CIS Benchmark",
  }
  
  # Apply each setting
  $settings.each |$setting_name, $setting_config| {
    
    # Ensure the registry key exists
    registry_key { $setting_config['registry_key']:
      ensure => present,
    }
    
    # Set the registry value
    registry_value { "${setting_config['registry_key']}\\${setting_config['registry_value']}":
      ensure  => present,
      type    => $setting_config['type'],
      data    => $setting_config['data'],
      require => Registry_key[$setting_config['registry_key']],
    }
    
    # Optional: Log compliance
    notify { "CIS ${setting_config['cis_control']}: ${setting_name}":
      message => "Setting ${setting_config['registry_value']} = ${setting_config['data']}",
      require => Registry_value["${setting_config['registry_key']}\\${setting_config['registry_value']}"],
    }
  }
  
  # Ensure Windows Defender service is running
  service { 'WinDefend':
    ensure => running,
    enable => true,
  }
}
```

#### `site-modules/profile/manifests/windows/baseline.pp`

```puppet
# site-modules/profile/manifests/windows/baseline.pp
# Base Windows configuration (can be expanded later)

class profile::windows::baseline {
  
  # Common Windows baseline
  notify { 'Applying Windows baseline configuration': }
  
  # Example: Ensure time sync is configured
  # service { 'W32Time':
  #   ensure => running,
  #   enable => true,
  # }
  
  # Include Defender CIS profile
  include profile::windows::defender_cis
  
  # Future: Add more baseline controls
  # include profile::windows::updates
  # include profile::windows::firewall
  # include profile::windows::audit_policy
}
```

---

## Scaling Strategy

### Current State: POC
```
Single Environment → Basic CIS Controls → Limited Data Hierarchy
```

### Scaling Dimensions

#### 1. **Vertical Scaling** (More Controls)

Add more CIS controls progressively:

```
Phase 1: Windows Defender (5-10 controls)
Phase 2: Firewall Settings (10-15 controls)
Phase 3: User Rights Assignment (20+ controls)
Phase 4: Audit Policy (30+ controls)
Phase 5: Advanced Security Settings (50+ controls)
```

Create separate profile classes:
```
profile::windows::defender_cis
profile::windows::firewall_cis
profile::windows::user_rights_cis
profile::windows::audit_policy_cis
```

#### 2. **Horizontal Scaling** (More Nodes)

Use Hiera hierarchy for differentiation:

```yaml
# data/locations/dc1.yaml (datacenter-specific)
# data/departments/finance.yaml (department-specific)
# data/environments/production.yaml (environment-specific)
```

Update `hiera.yaml`:
```yaml
hierarchy:
  - name: "Per-node"
    path: "nodes/%{trusted.certname}.yaml"
  
  - name: "Per-environment"
    path: "environments/%{facts.environment}.yaml"
  
  - name: "Per-department"
    path: "departments/%{facts.department}.yaml"
  
  - name: "Per-location"
    path: "locations/%{facts.location}.yaml"
  
  - name: "Per-role"
    path: "roles/%{facts.role}.yaml"
  
  - name: "Per-OS"
    path: "os/%{facts.os.family}.yaml"
  
  - name: "Common"
    path: "common.yaml"
```

#### 3. **Environment Scaling** (Multiple Environments)

Leverage r10k's Git branch mapping:

```
Git Branches:
├── production       → Stable, tested configurations
├── staging          → Pre-production testing
├── development      → Active development
└── feature/xyz      → Feature-specific testing
```

Agent configuration:
```ini
# puppet.conf on test agents
[agent]
environment = development

# puppet.conf on production agents
[agent]
environment = production
```

#### 4. **Module Scaling** (Reusability)

Convert profiles to component modules:

```
Current:  profile::windows::defender_cis (site-specific)
                    ↓
Future:   component::windows_defender (reusable)
          └── Consumed by multiple profiles
```

Structure:
```
site-modules/
└── component/
    └── windows_defender/
        ├── manifests/
        │   ├── init.pp
        │   ├── realtime_protection.pp
        │   └── cloud_protection.pp
        └── data/
            └── common.yaml
```

### Scaling Timeline

**Week 1-2: POC**
- Control repo created
- 5 Defender CIS controls
- Single environment
- 2-3 test nodes

**Month 1: Expand Controls**
- 20+ CIS controls (Defender + Firewall)
- Role-based Hiera hierarchy
- 10+ test nodes across roles

**Month 2-3: Production Readiness**
- 50+ CIS controls across multiple categories
- Multi-environment (dev/staging/prod)
- Location/department hierarchy
- 100+ nodes

**Month 4+: Enterprise Scale**
- Complete CIS L1 + L2 coverage
- Component module architecture
- Automated testing/validation
- 1000+ nodes

---

## Testing Workflow

### Initial Setup

1. **Deploy Control Repo**
```bash
# On Puppet Server
r10k deploy environment production -pv
```

2. **Test Agent Run**
```powershell
# On Windows agent
puppet agent -t --environment production

# Check applied resources
puppet resource registry_value 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection\DisableBehaviorMonitoring'
```

3. **Validate Configuration**
```powershell
# Check registry directly
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"

# Check Defender status
Get-MpPreference | Select-Object DisableBehaviorMonitoring, DisableRealtimeMonitoring, DisableScriptScanning
```

### Testing New Changes

**Development Workflow**:

```bash
# 1. Create feature branch
git checkout -b feature/add-firewall-controls

# 2. Make changes to Puppetfile, manifests, data

# 3. Commit and push
git add .
git commit -m "Add Windows Firewall CIS controls"
git push origin feature/add-firewall-controls

# 4. Deploy to test environment
r10k deploy environment feature_add-firewall-controls -pv

# 5. Test on agent
puppet agent -t --environment feature_add-firewall-controls --noop  # Dry run
puppet agent -t --environment feature_add-firewall-controls         # Apply

# 6. Validate results
# ... run tests ...

# 7. Merge to production when validated
git checkout production
git merge feature/add-firewall-controls
git push origin production
r10k deploy environment production -pv
```

### Automated Testing

Create a test script for validation:

```powershell
# test-defender-cis.ps1
$results = @()

# Test 18.9.15.1 - Behavior Monitoring
$behaviorMonitoring = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name DisableBehaviorMonitoring -ErrorAction SilentlyContinue
$results += [PSCustomObject]@{
    Control = "18.9.15.1"
    Setting = "Behavior Monitoring"
    Expected = 0
    Actual = $behaviorMonitoring.DisableBehaviorMonitoring
    Status = if($behaviorMonitoring.DisableBehaviorMonitoring -eq 0) {"PASS"} else {"FAIL"}
}

# Test 18.9.15.2 - Scan Downloads
$scanDownloads = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name DisableIOAVProtection -ErrorAction SilentlyContinue
$results += [PSCustomObject]@{
    Control = "18.9.15.2"
    Setting = "Scan Downloads"
    Expected = 0
    Actual = $scanDownloads.DisableIOAVProtection
    Status = if($scanDownloads.DisableIOAVProtection -eq 0) {"PASS"} else {"FAIL"}
}

# Display results
$results | Format-Table -AutoSize

# Exit with error if any failures
if($results | Where-Object {$_.Status -eq "FAIL"}) {
    Write-Error "CIS compliance checks failed"
    exit 1
}
```

---

## Best Practices

### 1. **Code Organization**

**DO**:
- Keep profiles small and focused (single responsibility)
- Use meaningful, descriptive names
- Document CIS control IDs in code
- Version your Puppetfile dependencies

**DON'T**:
- Put business logic in manifests/site.pp
- Hardcode values (use Hiera)
- Mix profiles and component modules
- Use legacy node inheritance

### 2. **Data Management**

**DO**:
- Use deep merges for complex hashes
- Provide sensible defaults in common.yaml
- Document all Hiera keys
- Use consistent naming conventions

**DON'T**:
- Override the same key at multiple levels unnecessarily
- Store sensitive data unencrypted (use eyaml or Vault)
- Create circular lookups
- Duplicate data across files

### 3. **r10k Workflow**

**DO**:
- Use feature branches for testing
- Deploy frequently
- Automate deployments via webhooks
- Use semantic versioning for modules

**DON'T**:
- Commit directly to production branch
- Deploy without testing
- Skip r10k deploys after Git updates
- Mix module sources (Forge vs Git)

### 4. **Security**

**DO**:
- Use Hiera-eyaml for sensitive data
- Audit control repo access
- Implement code review processes
- Test in isolated environments first

**DON'T**:
- Commit credentials to Git
- Allow untested code in production
- Skip validation steps
- Disable security controls without justification

### 5. **Documentation**

**DO**:
- Document CIS control mappings
- Maintain README in control repo
- Comment complex Puppet code
- Track exceptions/deviations

**DON'T**:
- Assume others know the context
- Leave undocumented overrides
- Skip changelog updates
- Ignore deprecation warnings

---

## Appendix A: Quick Reference

### Common Commands

```bash
# r10k deployment
r10k deploy environment <env_name> -pv          # Deploy specific environment
r10k deploy environment -p                       # Deploy all environments
r10k deploy display                              # Show what would be deployed

# Puppet agent
puppet agent -t                                  # Run agent
puppet agent -t --noop                          # Dry run
puppet agent -t --environment <env>             # Use specific environment
puppet agent -t --debug                         # Debug mode

# Check configuration
puppet config print environment                  # Show current environment
puppet config print modulepath                   # Show module search path
puppet lookup <key>                             # Test Hiera lookup
```

### File Locations

```
Control Repo:          /path/to/puppet-control-repo/
Puppet Environments:   /etc/puppetlabs/code/environments/
Modules (deployed):    /etc/puppetlabs/code/environments/<env>/modules/
Site Modules:          /etc/puppetlabs/code/environments/<env>/site-modules/
Hiera Data:           /etc/puppetlabs/code/environments/<env>/data/
```

---

## Appendix B: Troubleshooting

### Issue: r10k doesn't deploy changes

**Solution**:
```bash
# Check r10k config
cat /etc/puppetlabs/r10k/r10k.yaml

# Verify Git access
ssh -T git@github.com

# Manual deploy with verbose output
r10k deploy environment production -pv --trace
```

### Issue: Agent can't find module

**Solution**:
```bash
# Check modulepath
puppet config print modulepath

# Verify module is deployed
ls /etc/puppetlabs/code/environments/production/modules/

# Check Puppetfile syntax
cd /path/to/control-repo
r10k puppetfile check
```

### Issue: Registry changes not applying

**Solution**:
```powershell
# Check if Puppet has admin rights
whoami /priv

# Verify registry module is available
puppet module list | Select-String registry

# Test registry access manually
puppet resource registry_value 'HKLM\SOFTWARE\Test\Value'
```

### Issue: Hiera lookup returns wrong value

**Solution**:
```bash
# Debug Hiera lookup
puppet lookup <key> --explain

# Check hierarchy
cat /etc/puppetlabs/code/environments/<env>/hiera.yaml

# Validate YAML syntax
yamllint data/
```

---

## Conclusion

This testbed provides a solid foundation for:
- **Immediate**: Proving Puppet + r10k can manage Windows Defender
- **Short-term**: Establishing patterns for CIS compliance
- **Long-term**: Scaling to enterprise-wide Windows endpoint management

The modular structure allows incremental growth while maintaining code quality and operational stability.

### Next Steps

1. Initialize Git repository with provided structure
2. Configure r10k on Puppet Server
3. Deploy initial environment
4. Test on 2-3 Windows nodes
5. Validate CIS controls
6. Iterate and expand

### Support Resources

- **Puppet Documentation**: https://puppet.com/docs/puppet/latest/
- **r10k Documentation**: https://github.com/puppetlabs/r10k
- **CIS Benchmarks**: https://www.cisecurity.org/cis-benchmarks/
- **Puppet Forge**: https://forge.puppet.com/

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Author**: Infrastructure Team
