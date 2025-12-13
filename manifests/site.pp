
node default {}

# Target your specific Windows node (replace with the actual certname if different)
node 'thinkpad-l15-01.lan' {
  # CIS Benchmark Example: Ensure Real-Time Monitoring is ON
  # This corresponds to setting 'DisableAntiSpyware' to 0 (Disabled)
  $defender_key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender'

  registry_key { 'WindowsDefender_Policy':
    ensure => present,
    path   => $defender_key,
  }

  registry_value { 'RealTimeMonitoring_Value':
    ensure => present,
    path   => "${defender_key}\DisableAntiSpyware",
    data   => '0', # '0' means Disabled, which forces the setting ON.
    type   => dword,
    require => Registry_key['WindowsDefender_Policy'],
    notify  => Notify['RealTimeMonitoring_Change'],
  }

  notify { 'RealTimeMonitoring_Change':
    message => 'Windows Defender Real-Time Monitoring setting checked/enforced.',
  }
}
