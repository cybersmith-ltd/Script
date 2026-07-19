# Ensure the script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You must run this script as Administrator!"
    return
}

# Start User Feedback
Write-Host ""
Write-Host "# Cybersmith Nessus Scan Disable Settings Tool" -ForegroundColor DarkYellow
Write-Host "This will revert a device back to the default settings removing the standard changes required to make a Nessus scan work."
Write-Host "Changes are listed in green, errors in red and where no changes were required they are uncoloured."
Write-Host ""

Write-Host "# Commands Run" -ForegroundColor DarkYellow
Write-Host "If you wish to run them manually or add them to your own script these are the commands to run:"
Write-Host ""
Write-Host "Set-Service -Name ""RemoteRegistry"" -StartupType Disabled"
Write-Host "Remove-ItemProperty -Path ""HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"" -Name ""LocalAccountTokenFilterPolicy"""
Write-Host "Disable-NetFirewallRule -Name ""FPS-ICMP4-ERQ-In"""
Write-Host "Disable-NetFirewallRule -Name ""FPS-NB_Session-In-TCP"""
Write-Host "Disable-NetFirewallRule -Name ""FPS-SMB-In-TCP"""
Write-Host "Disable-NetFirewallRule -Name ""WMI-ASYNC-In-TCP"""
Write-Host "Disable-NetFirewallRule -Name ""WMI-RPCSS-In-TCP"""
Write-Host "Disable-NetFirewallRule -Name ""WMI-WINMGMT-In-TCP"""
Write-Host ""

# Revert Settings
Write-Host "# Revert Settings" -ForegroundColor DarkYellow

## Remote Reg
$remoteReg = Get-Service -Name "RemoteRegistry" -ErrorAction SilentlyContinue
if ($remoteReg) {
    if ($remoteReg.StartType -eq 'Disabled') {
        Write-Host "RemoteRegistry: Service startup type set to 'Disabled'. No action required."
    } else {
        Write-Host "RemoteRegistry: Service startup type set to '$($remoteReg.StartType)'. Changing to Disabled." -ForegroundColor Green
        Set-Service -Name "RemoteRegistry" -StartupType Disabled
    }

} else {
    Write-Host "RemoteRegistry: Cannot be found on device. This should not happen because this service is a core part of Windows." -ForegroundColor Red
}

## LocalAccountTokenFilterPolicy
$filterPolicyRegValueObject = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -ErrorAction SilentlyContinue
if ($filterPolicyRegValueObject) {
    Write-Host "LocalAccountTokenFilterPolicy: Value exists, removing it to disable setting." -ForegroundColor Green
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy"
} else {
    Write-Host "LocalAccountTokenFilterPolicy: Value does not exist = Disabled. No action required."
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
            if ($fr.Enabled -eq $false) {
                Write-Host "Firewall: $($rule.DisplayName) ($($fr.Profile)) = Disabled. No action required."
            } else {
                Write-Host "Firewall: $($rule.DisplayName) ($($fr.Profile)) = Enabled. Disabling it." -ForegroundColor Green
                Disable-NetFirewallRule -Name $rule.Name
            }
        }
    } else {
        Write-Host "Error: Rule not found: $($rule.DisplayName) ($($rule.Name))" -ForegroundColor Red
    }
}

# Complete
Write-Host "Complete"
