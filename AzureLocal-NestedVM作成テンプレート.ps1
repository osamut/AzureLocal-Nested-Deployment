### ステップ１開始： 疑似的な Azure local ノード (仮想マシン) の作成

# ノード名、ノードのIPアドレス、Hyper-Vスイッチ名を環境に合わせて記入
$nodeName = ""
$NATSwitchName = ""
$AzureLocalISOPath = ""
$VMFilePath = ""
$VMFileFullPath = Join-Path $VMFilePath -ChildPath "\$nodeName\Virtual Hard Disks\$nodeName.vhdx"
$VMStorageFilePath = Join-Path $VMFilePath -ChildPath "\$nodeName\Virtual Hard Disks\"

#仮想マシンのVHDXファイルの場所を環境に合わせて修正し、仮想マシンを作成
New-VM `
    -Name $nodeName  `
    -MemoryStartupBytes 32GB `
    -SwitchName $NATSwitchName `
    -Path $VMFilePath `
    -NewVHDPath $VMFileFullPath `
    -NewVHDSizeBytes 200GB `
    -Generation 2

# ダイナミックメモリを無効化
Set-VMMemory -VMName $nodeName -DynamicMemoryEnabled $false

# Azureポータルからダウンロードした最新のAzure Local ISOを仮想マシンにマウントしDVD起動設定
$DVD = Add-VMDvdDrive -VMName $nodeName -Path $AzureLocalISOPath -Passthru
Set-VMFirmware -VMName $nodeName -FirstBootDevice $DVD

# 仮想マシンのプロセッサ設定
Set-VM -VMname $nodeName -ProcessorCount 16
# 仮想マシンの既定のNICを一旦削除し、にAzure Local用の4つのNICを作成
Get-VMNetworkAdapter -VMName $nodeName | Remove-VMNetworkAdapter
Add-VmNetworkAdapter -VmName $nodeName -Name "NIC1" -SwitchName $NATSwitchName
Add-VmNetworkAdapter -VmName $nodeName -Name "NIC2" -SwitchName $NATSwitchName
Add-VmNetworkAdapter -VmName $nodeName -Name "NIC3" -SwitchName $NATSwitchName
Add-VmNetworkAdapter -VmName $nodeName -Name "NIC4" -SwitchName $NATSwitchName

# 仮想マシンに追加したNICのMac Address Spoofing設定を有効化
1..3 | ForEach-Object { 
    Set-VMNetworkAdapter -VMName $nodeName -MacAddressSpoofing On -AllowTeaming On 
}

# 仮想NICのトランクモードを有効化
Get-VmNetworkAdapter -VmName $nodeName |Set-VMNetworkAdapterVlan -Trunk -NativeVlanId 0 -AllowedVlanIdList 0-1000

# 仮想マシンのvTPMの有効化
$owner = Get-HgsGuardian UntrustedGuardian
$kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
Set-VMKeyProtector -VMName $nodename -KeyProtector $kp.RawData
Enable-VmTpm -VMName $nodeName

# Azure LocalのS2D (Software Defined Storage)用にデータ用仮想ディスクを６つ作成
$dataDrives =1..6 | ForEach-Object { New-VHD -Path "$VMStorageFilePath\DATA0$_.vhdx" -Dynamic -Size 100GB }
$dataDrives | ForEach-Object {
    Add-VMHardDiskDrive -Path $_.path -VMName $nodeName
}

# 仮想マシンのチェックポイントを無効化
Set-VM -VMName $nodeName -CheckpointType Disabled

# 仮想マシンの Nested を有効化
Set-VMProcessor -VMName $nodeName -ExposeVirtualizationExtensions $true -Verbose


# 仮想マシンのホストとの時刻同期を無効化
Get-VMIntegrationService -VMName $nodeName |Where-Object {$_.name -like "T*"}|Disable-VMIntegrationService

# 仮想マシンコンソールに接続し、仮想マシンを起動
vmconnect.exe localhost $nodeName
Start-Sleep -Seconds 5
Start-VM -Name $nodeName

### ステップ１終了

# -----------------------------------------------------------------------------------------------
#自動で再起動が始まるので次のステップに行くのを少し待つ


### ステップ２開始：　Azure Local ノードのネットワーク設定

# IPアドレス関連の情報を記入
$ManagementNICIP = ""
$DefaultGatewayIP = ""
$DNSServerIP = ""
$LocalAdminName = "administrator"
$password = ""

# NIC自動設定用に情報収集
$Node1macNIC1 = Get-VMNetworkAdapter -VMName $nodeName -Name "NIC1"
$Node1macNIC1.MacAddress
$Node1finalmacNIC1=$Node1macNIC1.MacAddress|ForEach-Object{($_.Insert(2,"-").Insert(5,"-").Insert(8,"-").Insert(11,"-").Insert(14,"-"))-join " "}
$Node1finalmacNIC1

$Node1macNIC2 = Get-VMNetworkAdapter -VMName $nodeName -Name "NIC2"
$Node1macNIC2.MacAddress
$Node1finalmacNIC2=$Node1macNIC2.MacAddress|ForEach-Object{($_.Insert(2,"-").Insert(5,"-").Insert(8,"-").Insert(11,"-").Insert(14,"-"))-join " "}
$Node1finalmacNIC2

$Node1macNIC3 = Get-VMNetworkAdapter -VMName $nodeName -Name "NIC3"
$Node1macNIC3.MacAddress
$Node1finalmacNIC3=$Node1macNIC3.MacAddress|ForEach-Object{($_.Insert(2,"-").Insert(5,"-").Insert(8,"-").Insert(11,"-").Insert(14,"-"))-join " "}
$Node1finalmacNIC3

$Node1macNIC4 = Get-VMNetworkAdapter -VMName $nodeName -Name "NIC4"
$Node1macNIC4.MacAddress
$Node1finalmacNIC4=$Node1macNIC4.MacAddress|ForEach-Object{($_.Insert(2,"-").Insert(5,"-").Insert(8,"-").Insert(11,"-").Insert(14,"-"))-join " "}
$Node1finalmacNIC4

# 自動ログオン用に管理者名とパスワードを処理
$pwdSecureString = ConvertTo-SecureString -Force -AsPlainText $password
$azsHCILocalCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $LocalAdminName, $pwdSecureString

# Mac アドレスをもとにNIC 名を変更
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {param($Node1finalmacNIC1) Get-NetAdapter -Physical | Where-Object {$_.MacAddress -eq $Node1finalmacNIC1} | Rename-NetAdapter -NewName "NIC1"} -ArgumentList $Node1finalmacNIC1
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {param($Node1finalmacNIC2) Get-NetAdapter -Physical | Where-Object {$_.MacAddress -eq $Node1finalmacNIC2} | Rename-NetAdapter -NewName "NIC2"} -ArgumentList $Node1finalmacNIC2
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {param($Node1finalmacNIC3) Get-NetAdapter -Physical | Where-Object {$_.MacAddress -eq $Node1finalmacNIC3} | Rename-NetAdapter -NewName "NIC3"} -ArgumentList $Node1finalmacNIC3
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {param($Node1finalmacNIC4) Get-NetAdapter -Physical | Where-Object {$_.MacAddress -eq $Node1finalmacNIC4} | Rename-NetAdapter -NewName "NIC4"} -ArgumentList $Node1finalmacNIC4

# NIC の DHCPを無効化
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {Set-NetIPInterface -InterfaceAlias "NIC1" -Dhcp Disabled}
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {Set-NetIPInterface -InterfaceAlias "NIC2" -Dhcp Disabled}
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {Set-NetIPInterface -InterfaceAlias "NIC3" -Dhcp Disabled}
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {Set-NetIPInterface -InterfaceAlias "NIC4" -Dhcp Disabled}

# 管理用NICに IPアドレス、ゲートウェイ、DNS を設定
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {New-NetIPAddress -InterfaceAlias "NIC1" -IPAddress $using:ManagementNICIP -PrefixLength 16 -AddressFamily IPv4 -DefaultGateway $using:DefaultGatewayIP}
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {Set-DnsClientServerAddress -InterfaceAlias "NIC1" -ServerAddresses $using:DNSServerIP}

# IPv6 を無効化
Disable-NetAdapterBinding -Name * -ComponentID ms_tcpip6

# 再起動前に DVD を外しておく　※BitLocker 暗号化処理時のエラーを防ぐため
Get-VM -VMName $nodename | Get-VMDVDDrive | Set-VMDVDDrive -Path $Null

# ノード名を変更し、仮想マシンを再起動
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {Rename-Computer -NewName $Using:nodeName -LocalCredential $Using:azsHCILocalCreds -Force -Verbose}
Stop-VM -Name $nodeName
Start-Sleep -Seconds 5
Start-VM -Name $nodeName

### ステップ２終了


