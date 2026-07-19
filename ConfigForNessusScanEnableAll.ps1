# Ensure the script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You must run this script as Administrator!"
    return
}

# Start User Feedback
Write-Host ""
Write-Host "# Cybersmith Nessus Scan Enable Settings Tool" -ForegroundColor DarkYellow
Write-Host "This will enable the settings required for a Nessus to work on a default Windows installation."
Write-Host "Changes are listed in green, errors in red and where no changes were required they are uncoloured."
Write-Host ""

Write-Host "# Commands Run" -ForegroundColor DarkYellow
Write-Host "If you wish to run them manually or add them to your own script these are the commands to run:"
Write-Host ""
Write-Host "Set-Service -Name ""RemoteRegistry"" -StartupType Manual"
Write-Host "Set-ItemProperty -Path ""HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"" -Name ""LocalAccountTokenFilterPolicy"" -Value 1 -ErrorAction SilentlyContinue"
Write-Host "Enable-NetFirewallRule -Name ""FPS-ICMP4-ERQ-In"""
Write-Host "Enable-NetFirewallRule -Name ""FPS-NB_Session-In-TCP"""
Write-Host "Enable-NetFirewallRule -Name ""FPS-SMB-In-TCP"""
Write-Host "Enable-NetFirewallRule -Name ""WMI-ASYNC-In-TCP"""
Write-Host "Enable-NetFirewallRule -Name ""WMI-RPCSS-In-TCP"""
Write-Host "Enable-NetFirewallRule -Name ""WMI-WINMGMT-In-TCP"""
Write-Host ""

# Enabling Settings
Write-Host "# Enabling Settings" -ForegroundColor DarkYellow

## Remote Reg
$remoteReg = Get-Service -Name "RemoteRegistry" -ErrorAction SilentlyContinue
if ($remoteReg) {
    if ($remoteReg.StartType -eq 'Disabled') {
        Write-Host "RemoteRegistry: Service startup type set to 'Disabled'. Changing to Manual." -ForegroundColor Green
        Set-Service -Name "RemoteRegistry" -StartupType Manual
    } else {
        Write-Host "RemoteRegistry: Service startup type set to '$($remoteReg.StartType)'. No action required."
    }

} else {
    Write-Host "RemoteRegistry: Cannot be found on device. This should not happen because this service is a core part of Windows." -ForegroundColor Red
}

## LocalAccountTokenFilterPolicy
$filterPolicyRegValueObject = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -ErrorAction SilentlyContinue
if ($filterPolicyRegValueObject) {
    if ($filterPolicyRegValueObject.LocalAccountTokenFilterPolicy -eq 1) {
        Write-Host "LocalAccountTokenFilterPolicy: Value exists and set to 1 = Enabled. No action required."
    } else {
        Write-Host "LocalAccountTokenFilterPolicy: Value exists and set to 0 = Disabled. Setting it to 1 to enable it." -ForegroundColor Green
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
    }
} else {
    Write-Host "LocalAccountTokenFilterPolicy: Value does not exist = Disabled. Creating the key and setting it to 1 to enable it." -ForegroundColor Green
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1
}

## Firewall
$firewallRules = @(
    @{ DisplayName = "File and Printer Sharing (Echo Request - ICMPv4-In)"; Name = "FPS-ICMP4-ERQ-In" },
    @{ DisplayName = "File and Printer Sharing (NB-Session-In)"; Name = "FPS-NB_Session-In-TCP" },
    @{ DisplayName = "File and Printer Sharing (SMB-In)"; Name = "FPS-SMB-In-TCP" },
    @{ DisplayName = "Windows Management Instrumentation (ASync-In)"; Name = "WMI-ASYNC-In-TCP" },
    @{ DisplayName = "Windows Management Instrumentation (DCOM-In)"; Name = "WMI-RPCSS-In-TCP" },
    @{ DisplayName = "Windows Management Instrumentation (WMI-In)"; Name = "WMI-WINMGMT-In-TCP" }
)

foreach ($rule in $firewallRules) {
    $foundRules = Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue

    if ($foundRules) {
        foreach ($fr in $foundRules) {
            if ($fr.Enabled -eq $true) {
                Write-Host "Firewall: $($rule.DisplayName) ($($fr.Profile)) = Enabled. No action required."
            } else {
                Write-Host "Firewall: $($rule.DisplayName) ($($fr.Profile)) = Disabled. Enabling it." -ForegroundColor Green
                Enable-NetFirewallRule -Name $rule.Name
            }
        }
    } else {
        Write-Host "Error: Rule not found: $($rule.DisplayName) ($($rule.Name))" -ForegroundColor Red
    }
}

# Complete
Write-Host "Complete"
