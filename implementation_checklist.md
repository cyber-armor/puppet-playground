# Implementation Checklist: Puppet r10k Windows Defender POC

## Pre-Implementation (1-2 days)

### Infrastructure Preparation
- [ ] Puppet Server deployed via official Helm chart
- [ ] Puppet Server accessible (verify: `curl https://puppet-server:8140/status/v1/simple`)
- [ ] Git repository created (GitHub/GitLab/Bitbucket)
- [ ] Git repository accessible from Puppet Server
- [ ] At least 1-2 Windows test nodes available
- [ ] Windows nodes can reach Puppet Server on port 8140

### Access & Permissions
- [ ] Git repository SSH keys or credentials configured
- [ ] r10k has read access to Git repository
- [ ] Windows test nodes have admin credentials available
- [ ] Firewall rules allow Puppet traffic (port 8140)

### Team Readiness
- [ ] Team members have Git repository access
- [ ] Team familiar with basic Git workflow (branch, commit, push)
- [ ] Team has reviewed documentation
- [ ] Roles and responsibilities assigned

---

## Implementation Phase 1: Repository Setup (Day 1)

### Step 1: Clone Control Repository Template
```bash
# Download the provided puppet-control-repo directory
# Initialize git
cd puppet-control-repo
git init
git add .
git commit -m "Initial commit - Windows Defender CIS POC"
```

**Verification**: 
- [ ] All files present (Puppetfile, hiera.yaml, manifests/, data/, site-modules/)
- [ ] No syntax errors: `find . -name "*.pp" -exec puppet parser validate {} \;`

### Step 2: Customize for Your Environment
```bash
# Edit data/nodes/.gitkeep or create actual node files
# Update puppet.conf settings if needed
# Verify Hiera data structure matches your needs
```

**Verification**:
- [ ] Node certnames match your actual nodes
- [ ] Git remote configured: `git remote -v`
- [ ] YAML files valid: `yamllint data/`

### Step 3: Push to Git Remote
```bash
git remote add origin https://github.com/your-org/puppet-control-repo.git
git branch -M production
git push -u origin production
```

**Verification**:
- [ ] Code visible in Git remote
- [ ] Branch named 'production'
- [ ] All files pushed successfully

---

## Implementation Phase 2: Puppet Server Configuration (Day 1)

### Step 4: Configure r10k

**Via Helm Chart** (`values.yaml`):
```yaml
r10k:
  enabled: true
  sources:
    puppet:
      remote: 'https://github.com/your-org/puppet-control-repo.git'
      basedir: '/etc/puppetlabs/code/environments'
```

**Or Manual Configuration** (`/etc/puppetlabs/r10k/r10k.yaml`):
```yaml
---
cachedir: '/var/cache/r10k'
sources:
  puppet:
    remote: 'https://github.com/your-org/puppet-control-repo.git'
    basedir: '/etc/puppetlabs/code/environments'
```

**Verification**:
- [ ] r10k config file exists
- [ ] Git remote accessible: `git ls-remote <repo_url>`
- [ ] r10k can read config: `r10k puppetfile check`

### Step 5: Deploy Code with r10k
```bash
# First deployment
r10k deploy environment production -pv

# Verify deployment
ls -la /etc/puppetlabs/code/environments/production/
```

**Verification**:
- [ ] Environment directory created
- [ ] Modules downloaded (check `modules/` directory)
- [ ] Site modules present (`site-modules/` directory)
- [ ] No errors in r10k output

### Step 6: Test Module Dependencies
```bash
# Check required modules are installed
ls /etc/puppetlabs/code/environments/production/modules/

# Should see:
# - stdlib/
# - registry/
# - pwshlib/
# - dsc_lite/
```

**Verification**:
- [ ] All Puppetfile modules downloaded
- [ ] Module versions match Puppetfile
- [ ] No module conflicts reported

---

## Implementation Phase 3: Windows Agent Setup (Day 1-2)

### Step 7: Install Puppet Agent on Windows Nodes

**Option A: MSI Installer**
```powershell
# Download and install manually
# Or via Chocolatey:
choco install puppet-agent -y
```

**Option B: Silent Installation**
```powershell
msiexec /qn /norestart /i puppet-agent-x64-latest.msi `
  PUPPET_MASTER_SERVER=puppet-server.example.com
```

**Verification**:
- [ ] Puppet installed: `puppet --version`
- [ ] Service exists: `Get-Service puppet`
- [ ] Puppet bin in PATH

### Step 8: Configure Puppet Agent
```ini
# C:\ProgramData\PuppetLabs\puppet\etc\puppet.conf

[main]
server = puppet-server.example.com
environment = production

[agent]
certname = win-ws-001.example.com
runinterval = 30m
```

**Verification**:
- [ ] Config file exists
- [ ] Server hostname correct
- [ ] Certname is FQDN format
- [ ] Can reach server: `Test-NetConnection puppet-server.example.com -Port 8140`

### Step 9: Request and Sign Certificate
```powershell
# On Windows node
puppet agent -t

# On Puppet Server
puppetserver ca list
puppetserver ca sign --certname win-ws-001.example.com

# On Windows node (run again after signing)
puppet agent -t
```

**Verification**:
- [ ] Certificate request created
- [ ] Certificate signed on server
- [ ] Agent retrieves signed certificate
- [ ] No SSL errors

---

## Implementation Phase 4: Testing & Validation (Day 2)

### Step 10: Initial Dry Run
```powershell
# On Windows node
puppet agent -t --noop
```

**Verification**:
- [ ] Catalog compiles without errors
- [ ] Hiera data loads correctly
- [ ] Profile classes found
- [ ] Registry resources planned

### Step 11: Apply Configuration
```powershell
# On Windows node
puppet agent -t
```

**Review Output for**:
- [ ] No compilation errors
- [ ] Registry keys created
- [ ] Registry values set
- [ ] Services managed
- [ ] All CIS controls applied

### Step 12: Validate Registry Settings
```powershell
# Check registry directly
Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"

# Expected values:
# DisableBehaviorMonitoring: 0
# DisableIOAVProtection: 0
# DisableScriptScanning: 0
# DisableRealtimeMonitoring: 0
```

**Verification**:
- [ ] DisableBehaviorMonitoring = 0
- [ ] DisableIOAVProtection = 0
- [ ] DisableScriptScanning = 0
- [ ] DisableRealtimeMonitoring = 0
- [ ] SpynetReporting = 2

### Step 13: Run Validation Script
```powershell
# Run the provided test script
.\Test-DefenderCIS.ps1
```

**Expected Result**:
```
Total Tests: 5
Passed: 5
Failed: 0
Compliance: 100%

✓ CIS compliance validation PASSED
```

**Verification**:
- [ ] All tests pass
- [ ] 100% compliance
- [ ] No errors in script output
- [ ] Defender service running

### Step 14: Verify Idempotency
```powershell
# Run puppet agent multiple times
puppet agent -t
puppet agent -t
puppet agent -t

# Should show no changes after first run
```

**Verification**:
- [ ] Second run shows no changes
- [ ] Third run shows no changes
- [ ] Registry values remain stable
- [ ] No flapping resources

---

## Post-Implementation (Day 3+)

### Documentation
- [ ] Document actual node certnames used
- [ ] Record any customizations made
- [ ] Update README with environment-specific details
- [ ] Document any issues encountered and solutions

### Knowledge Transfer
- [ ] Demo to team members
- [ ] Walk through Git workflow
- [ ] Explain Hiera hierarchy
- [ ] Show how to add new controls

### Next Steps Planning
- [ ] Identify additional nodes to onboard
- [ ] Plan which CIS controls to add next
- [ ] Schedule training sessions
- [ ] Define runbook for common operations

---

## Common Issues & Solutions

### Issue: r10k deploy fails with "Permission denied"
**Solution**: 
```bash
# Check SSH key
ssh -T git@github.com

# Or configure Git credentials
git config --global credential.helper store
```

### Issue: Puppet agent can't retrieve catalog
**Solution**:
```powershell
# Check connectivity
Test-NetConnection puppet-server.example.com -Port 8140

# Check certificate
puppet agent -t --debug | Select-String -Pattern "certificate|SSL"

# Regenerate if needed
puppet ssl clean
puppet agent -t
```

### Issue: Registry values not applying
**Solution**:
```powershell
# Verify running as admin
[Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544'

# Check module availability
puppet module list | Select-String registry

# Manual registry test
puppet resource registry_value 'HKLM\SOFTWARE\Test\Value'
```

### Issue: Hiera lookup returns wrong value
**Solution**:
```bash
# Debug lookup on server
puppet lookup --node win-ws-001.example.com --explain \
  profile::windows::defender_cis::manage_defender

# Check YAML syntax
yamllint data/os/windows.yaml

# Verify hierarchy
cat /etc/puppetlabs/code/environments/production/hiera.yaml
```

---

## Success Criteria

Your POC is complete and successful when:

### Technical Criteria
- [x] Code deployed via r10k without errors
- [x] At least 1 Windows node managed
- [x] All 5 Windows Defender CIS controls applied
- [x] Validation script shows 100% compliance
- [x] Configuration is idempotent (no changes on repeat runs)
- [x] Windows Defender service running and enabled

### Operational Criteria  
- [x] Team can modify settings via Hiera
- [x] Team can deploy changes via Git → r10k
- [x] Documentation is complete and understood
- [x] Workflow is repeatable

### Business Criteria
- [x] Security team validates CIS compliance
- [x] Stakeholders approve approach
- [x] ROI/value demonstrated
- [x] Path to production defined

---

## Appendix: Quick Command Reference

### Git Operations
```bash
git status                                    # Check current state
git add .                                     # Stage changes
git commit -m "message"                      # Commit changes
git push                                     # Push to remote
git checkout -b feature/name                 # Create feature branch
```

### r10k Operations
```bash
r10k deploy environment production -pv       # Deploy production
r10k deploy environment -p                   # Deploy all environments
r10k puppetfile install                      # Install modules only
```

### Puppet Operations
```powershell
puppet agent -t                              # Run agent
puppet agent -t --noop                       # Dry run
puppet lookup <key> --node <certname>       # Test Hiera lookup
puppet resource registry_value <path>        # Query registry
```

### Validation
```powershell
.\Test-DefenderCIS.ps1                      # Run compliance test
Get-Service WinDefend                        # Check Defender service
Get-MpPreference | Select-Object Disable*   # Check Defender settings
```

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Status**: Ready for Implementation
