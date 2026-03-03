# Ensure the script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You must run this script as Administrator!"
    return
}

# Variables
$remoteRegistryServiceName = "RemoteRegistry"

$filterPolicyRegKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$filterPolicyRegValue = "LocalAccountTokenFilterPolicy"

$firewallRules = @(
    @{ DisplayName = "File and Printer Sharing (Echo Request - ICMPv4-In)"; Name = "FPS-ICMP4-ERQ-In" },
    @{ DisplayName = "File and Printer Sharing (NB-Session-In)"; Name = "FPS-NB_Session-In-TCP" },
    @{ DisplayName = "File and Printer Sharing (SMB-In)"; Name = "FPS-SMB-In-TCP" },
    @{ DisplayName = "Windows Management Instrumentation (ASync-In)"; Name = "WMI-ASYNC-In-TCP" },
    @{ DisplayName = "Windows Management Instrumentation (DCOM-In)"; Name = "WMI-RPCSS-In-TCP" },
    @{ DisplayName = "Windows Management Instrumentation (WMI-In)"; Name = "WMI-WINMGMT-In-TCP" }
)

# Settings
function SettingSummary {
    Write-Host "## Setting Summary:"
    $remoteReg = Get-Service -Name $remoteRegistryServiceName -ErrorAction SilentlyContinue
    if ($remoteReg) {
        if ($remoteReg.StartType -eq 'Disabled') {
            Write-Host "RemoteRegistry: Service startup type set to 'Disabled'." -ForegroundColor Red
        } else {
            Write-Host "RemoteRegistry: Service startup type set to '$($remoteReg.StartType)'." -ForegroundColor Green
        }

    } else {
        Write-Host "RemoteRegistry: Cannot be found on device." -ForegroundColor Red
    }

    $filterPolicyRegValueObject = Get-ItemProperty -Path $filterPolicyRegKey -Name $filterPolicyRegValue -ErrorAction SilentlyContinue
    if ($filterPolicyRegValueObject) {
        if ($filterPolicyRegValueObject.LocalAccountTokenFilterPolicy -eq 1) {
            Write-Host "LocalAccountTokenFilterPolicy: Value exists and set to 1 = Enabled." -ForegroundColor Green
        } else {
            Write-Host "LocalAccountTokenFilterPolicy: Value exists and set to 0 = Disabled." -ForegroundColor Red
        }
    } else {
        Write-Host "LocalAccountTokenFilterPolicy: Value does not exist = Disabled." -ForegroundColor Red
    }

    foreach ($rule in $firewallRules) {
        $foundRules = Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue

        if ($foundRules) {
            foreach ($fr in $foundRules) {
                if ($fr.Enabled -eq $true) {
                    Write-Host "Firewall: $($rule.DisplayName) ($($fr.Profile)) = Enabled." -ForegroundColor Green
                } else {
                    Write-Host "Firewall: $($rule.DisplayName) ($($fr.Profile)) = Disabled." -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Error: Rule not found: $($rule.DisplayName) ($($rule.Name))" -ForegroundColor Red
        }
    }
}

# Remote Registry
function RemoteRegistry($enable, $customMode) {
    Write-Host "## RemoteRegistry Service"
    $remoteReg = Get-Service -Name $remoteRegistryServiceName -ErrorAction SilentlyContinue
    if ($remoteReg) {
        if ($enable) {
            if ($remoteReg.StartType -eq 'Disabled') {
                if ($customMode) {
                    Write-Host "The RemoteRegistry service is set to 'Disabled'. Would you like to set it to 'Manual'?"
                    $remoteRegAction = Read-Host "Type 'y' to set it to 'Manual' or 'n' to leave it as 'Disabled'"
                } else {
                    $remoteRegAction = "y"
                }

                switch ($remoteRegAction) {
                    "y" {
                        Write-Host "Change Made: RemoteRegistry service startup type is 'Disabled'. Setting to 'Manual'."
                        Set-Service -Name $remoteRegistryServiceName -StartupType Manual
                    }
                    "n" {
                        Write-Host "No Change Made: RemoteRegistry service startup type has been left as 'Disabled'."
                    }
                    default {
                        Write-Warning "Invalid option: $remoteRegAction. Please run the script again and type 'y' or 'n'."
                        return
                    }
                }
            } else {
                Write-Host "No Change Required: RemoteRegistry service startup type is not disabled and already set to '$($remoteReg.StartType)'."
            }
        } else {
            if ($remoteReg.StartType -ne 'Disabled') {
                if ($customMode) {
                    Write-Host "The RemoteRegistry service startup type is set to '$($remoteReg.StartType)'. Would you like to disable it?"
                    $remoteRegAction = Read-Host "Type 'y' to set it to 'Disabled' or 'n' to leave it as '$($remoteReg.StartType)'"
                } else {
                    $remoteRegAction = "y"
                }

                switch ($remoteRegAction) {
                    "y" {
                        Write-Host "Change Made: RemoteRegistry service startup type changed from '$($remoteReg.StartType)' to 'Disabled'."
                        Set-Service -Name $remoteRegistryServiceName -StartupType Disabled
                    }
                    "n" {
                        Write-Host "No Change Made: RemoteRegistry service startup type has been left as '$($remoteReg.StartType)'."
                    }
                    default {
                        Write-Warning "Invalid option: $remoteRegAction. Please run the script again and type 'y' or 'n'."
                        return
                    }
                }
            } else {
                Write-Host "No Change Required: RemoteRegistry service startup type is disabled."
            } 
        }
    } else {
        Write-Warning "Error: RemoteRegistry service not found on this system."
    }
    Write-Host ""
}

# LocalAccountTokenFilterPolicy
function LocalAccountTokenFilterPolicy($enable, $customMode) {
    Write-Host "## LocalAccountTokenFilterPolicy"

    $value = Get-ItemProperty -Path $filterPolicyRegKey -Name $filterPolicyRegValue -ErrorAction SilentlyContinue

    if ($enable) {
        if ($value) {
            if ($value.LocalAccountTokenFilterPolicy -eq 1) {
                Write-Host "No Change Required: LocalAccountTokenFilterPolicy exists and is enabled."
            } else {
                if ($customMode) {
                    Write-Host "The LocalAccountTokenFilterPolicy value exists, but is not set to 1. Would you like to set it to 1 to enable it?"
                    $filterPolicyAction = Read-Host "Type 'y' to set it to 1 or 'n' not to"
                } else {
                    $filterPolicyAction = "y"
                }

                switch ($filterPolicyAction) {
                    "y" {
                    Write-Host "Change Made: LocalAccountTokenFilterPolicy set to 1 to enable it."
                    Set-ItemProperty -Path $filterPolicyRegKey -Name $filterPolicyRegValue -Value 1
                    }
                    "n" {
                        Write-Host "No Change Made: The LocalAccountTokenFilterPolicy has been left set to 0."
                    }
                    default {
                        Write-Warning "Invalid option: $filterPolicyAction. Please run the script again and type 'y' or 'n'."
                        return
                    }
                }

            }
        } else {
            if ($customMode) {
                Write-Host "The LocalAccountTokenFilterPolicy value does not exist. Would you like to create it and set it to 1 to enable it?"
                $filterPolicyAction = Read-Host "Type 'y' to create it or 'n' not to"
            } else {
                $filterPolicyAction = "y"
            }

            switch ($filterPolicyAction) {
                "y" {
                    Write-Host "Change Made: LocalAccountTokenFilterPolicy created and set to 1."
                    Set-ItemProperty -Path $filterPolicyRegKey -Name $filterPolicyRegValue -Value 1
                }
                "n" {
                    Write-Host "No Change Made: The LocalAccountTokenFilterPolicy value has not been created."
                }
                default {
                    Write-Warning "Invalid option: $filterPolicyAction. Please run the script again and type 'y' or 'n'."
                    return
                }
            }
        }
    } else {
        if ($value) {
            if ($customMode) {
                Write-Host "The LocalAccountTokenFilterPolicy value exists. Would you like to delete it?"
                $filterPolicyAction = Read-Host "Type 'y' to delete it or 'n' not to"
            } else {
                $filterPolicyAction = "y"
            }

            switch ($filterPolicyAction) {
                "y" {
                    Write-Host "Change Made: The LocalAccountTokenFilterPolicy registry value has been deleted."
                    Remove-ItemProperty -Path $filterPolicyRegKey -Name $filterPolicyRegValue -Force
                }
                "n" {
                    Write-Host "No Change Made: The LocalAccountTokenFilterPolicy value has been left in the registry."
                }
                default {
                    Write-Warning "Invalid option: $filterPolicyAction. Please run the script again and type 'y' or 'n'."
                    return
                }
            }
        } else {
            Write-Host "No Change Required: LocalAccountTokenFilterPolicy value does not exist."
        }
    }
    Write-Host ""
}

# Firewall
function Firewall($enable, $customMode) {
    Write-Host "## Firewall"
    foreach ($rule in $firewallRules) {
        $foundRules = Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue

        if ($foundRules) {
            foreach ($fr in $foundRules) {
                if ($enable) {
                    if ($fr.Enabled -eq $true) {
                        Write-Host "No Change Required: $($rule.DisplayName) ($($fr.Profile)) is already enabled."
                    } else {
                        if ($customMode) {
                            Write-Host "The $($rule.DisplayName) ($($fr.Profile)) rule is disabled. Would you like to enable it?"
                            $firewallAction = Read-Host "Type 'y' to enable it or 'n' to leave it disabled."
                        } else {
                            $firewallAction = "y"
                        }

                        switch ($firewallAction) {
                            "y" {
                                Write-Host "Change Made: $($rule.DisplayName) ($($fr.Profile)) rule currently disabled. Enabling rule."
                                Enable-NetFirewallRule -Name $fr.Name
                            }
                            "n" {
                                Write-Host "No Change Made: The $($rule.DisplayName) ($($fr.Profile)) rule has been left disabled."
                            }
                            default {
                                Write-Warning "Invalid option: $firewallAction. Please run the script again and type 'y' or 'n'."
                                return
                            }
                        }
                    }
                }
                else {
                    if ($fr.Enabled -eq $false) {
                        Write-Host "No Change Required: $($rule.DisplayName) ($($fr.Profile)) is already disabled."
                    } else {
                        if ($customMode) {
                            Write-Host "The $($rule.DisplayName) ($($fr.Profile)) rule is enabled. Would you like to disable it?"
                            $firewallAction = Read-Host "Type 'y' to disable it or 'n' to leave it enabled."
                        } else {
                            $firewallAction = "y"
                        }

                        switch ($firewallAction) {
                            "y" {
                                Write-Host "Change Made: The $($rule.DisplayName) ($($fr.Profile)) rule has been disabled."
                                Disable-NetFirewallRule -Name $fr.Name
                            }
                            "n" {
                                Write-Host "No Change Made: The $($rule.DisplayName) ($($fr.Profile)) rule has been left enabled."
                            }
                            default {
                                Write-Warning "Invalid option: $firewallAction. Please run the script again and type 'y' or 'n'."
                                return
                            }
                        }
                    }
                }
            }
        } else {
            Write-Host "Error: Rule not found: $($rule.DisplayName) ($($rule.Name))"
        }
    }
    Write-Host ""
}

# Enable or disable the settings
function Enable() {
    Write-Host "## Enable or Disable Settings"
    $enableAction = Read-Host "Type 'on' to enable or 'off' to disable the scan settings"
    switch ($enableAction) {
        "on" {
            Write-Host "On: ENABLING Nessus Scan Settings."
            Write-Host ""
            return $true
        }
        "off" {
            Write-Host "Off: DISABLING Nessus Scan Settings."
            Write-Host ""
            return $false
        }
        default {
            Write-Warning "Invalid option: $enableAction. Run the script again and type 'on' or 'off'."
            Write-Host ""
            return $null
        }
    }
}

# STANDARD or CUSTOM mode
Write-Host "## Cybersmith Nessus Scan Settings Tool:"
Write-Host "This tool has 3 modes:"
Write-Host "STANDARD (Default): Applies our recommended settings automatically."
Write-Host "CUSTOM: Requires you to approve each change manually."
Write-Host "INFO: Lists the current configuration of each setting and makes no changes."
$modeAction = Read-Host "Just press enter for the default STANDARD mode, or type 'custom' or 'info' for those modes"
switch ($modeAction) {
    { $_ -in "", "standard" } {
        Write-Host "Running in STANDARD Mode."
        Write-Host ""

        $enable = Enable
        RemoteRegistry $enable $false
        LocalAccountTokenFilterPolicy $enable $false
        Firewall $enable $false
        SettingSummary
    }
    "custom" {
        Write-Host "Running in CUSTOM Mode."
        Write-Host ""

        $enable = Enable
        RemoteRegistry $enable $true
        LocalAccountTokenFilterPolicy $enable $true
        Firewall $enable $true
        SettingSummary
    }
    "info" {
        Write-Host "Running in INFO Mode."
        Write-Host ""

        SettingSummary
    }
    default {
        Write-Warning "Invalid option: $modeAction. Run the script again and press enter to use the default STANDARD mode, or type 'custom' or 'info' for those modes."
    }
}
Write-Host "Complete"
