node 'thinkpad-l15-01.lan' {
  # CIS Benchmark Example: Ensure Real-Time Monitoring is ON
  # Changed: Single quotes to double quotes, and single backslashes to double backslashes (\\).
  $defender_key = "HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\Windows Defender"

  registry_key { 'WindowsDefender_Policy':
    ensure => present,
    path   => $defender_key,
  }

  registry_value { 'RealTimeMonitoring_Value':
    ensure => present,
    path   => "${defender_key}\\DisableAntiSpyware", # Path interpolation now works correctly
    data   => '0',
    type   => dword,
    require => Registry_key['WindowsDefender_Policy'],
    notify  => Notify['RealTimeMonitoring_Change'],
  }

  notify { 'RealTimeMonitoring_Change':
    message => 'Windows Defender Real-Time Monitoring setting checked/enforced.',
  }
}
