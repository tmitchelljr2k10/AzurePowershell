# CONNECT TO AZURE VIA POWERSHELL

# Login to Azure via PowerShell:

    # Login-AzureRmAccount

# Select Your Subscription (if necessary):

    # Select-AzureRMSubscription -SubscriptionName "Pay-As-You-Go"

Write-Host "   "
Write-Host "   "
Write-Host "   IMPORTANT! PLEASE READ THE FOLLOWING NOTES BEFORE USING THIS SCRIPT!"
Write-Host "   --------------------------------------------------------------------"
Write-Host "   "
Write-Host "   The purpose of this script is to provide a streamlined ability to create a dual-NIC virtual Windows Server in Azure."
Write-Host "   "
Write-Host "   This script is provided AS-IS with no support offered. Please test this script in your lab environment first, before using it in production."
Write-Host "   "
Write-Host "   "
Write-Host "   This script should be modified before you can use it!"
Write-Host "   Variables under SET SCRIPT VARIABLES within the script must be replaced with your own values. Do not forget the quotation marks."
Write-Host "   "
Write-Host "   This script creates a new Resource Group and Storage Account for each VM it provisions."
Write-Host "   "
Write-Host "   storagename must be unique and cannot include any spaces or capital letters"
Write-Host "   vNetPrefix value MUST encompass both the subnet1addressprefix and subnet2addressprefix"
Write-Host "   VMSize must be a valid size for your chosen location"
Write-Host "   sku value must be valid for your location"
Write-Host "         -run Get-AzureRmVMImageSku to obtain a list of valid options "
Write-Host "              -When prompted for location, enter the location you plan to deploy your VM to"
Write-Host "              -When prompted for PublisherName, enter MicrosoftWindowsServer"
Write-Host "              -When prompted for Offer, enter WindowsServer"
Write-Host "   "
Write-Host "   "
Write-Host "   Documentation is included within the script itself."
Write-Host "   "
Write-Host "   If you run this script without editing it, it will provision the following resources:"
Write-Host "   "
Write-Host "         Resource Group: MyResourceGroup"
Write-Host "         Location: WestUS"
Write-Host "         Storage Account: WILL PROMPT YOU FOR NAME"
Write-Host "         Storage Type: Standard_LRS"
Write-Host "         First Subnet: Subnet1"
Write-Host "         Subnet1 Subnetting: 192.168.1.0/24"
Write-Host "         Second Subnet: Subnet2"
Write-Host "         Subnet2 Subnetting: 192.168.2.0/24"
Write-Host "         Virtual Network: myVnet"
Write-Host "         Virtual Network Subnet: 192.168.0.0/16"
Write-Host "         VM Size: Standard_A2_v2"
Write-Host "         Computer Name: SERVER01"
Write-Host "         VM Name: SERVER01"
Write-Host "         Installed OS: Windows Server 2016 Datacenter"
Write-Host "   "
Write-Host "   If you have not modified the script yet and do not wish to use the default settings above, please hit N below and edit the script with your own values before running it again."
Write-Host "   "
write-host -nonewline "   Continue running script? (Y/N) "
$response = read-host
if ( $response -ne "Y" ) { exit }
Write-Host "   "
Write-Host "   "


# SET SCRIPT VARIABLES

# Use the information below to modify this script for your environment.

# $rgn: Provide a name for your Resource Group
# $location: Provide your preferred Azure datacenter location 
# $storagename: Provide a name for your Storage Account (must be unique with no spaces or capital letters)
# $storagesku: Enter the disk type you wish to use
# $subnet1name: Enter a name for your first subnet
# $subnet1addressprefix: Enter an address prefix for your first subnet
# $subnet2name: Enter a name for your second subnet
# $subnet2addressprefix: Enter an address prefix for your second subnet
# $vNetName: Enter a name for your Virtual Network
# $vNetPrefix: Supply an address prefix for your Virtual Network (must encompass both your first and second subnet prefixes)
# $VMSize: What size VM do you want to provision?
# $computername: Provide a Computer Name for the VM
# $VMName: provide a name for the VM (usually the same as the Computer Name)
# $sku: What OS image do you want to use?  Run Get-AzureRmVMImageSKU for a list of options

$rgn = "MyResourceGroupNew"
$location="WestUS"
$storagename=Read-Host -Prompt 'Input a unique storage account name (ie. labstorageacct097654) NO CAPITAL LETTERS'
$storagesku="Standard_LRS"
$subnet1name="Subnet1"
$subnet1addressprefix="192.168.1.0/24"
$subnet2name="Subnet2"
$subnet2addressprefix="192.168.2.0/24"
$vNetName="myVnet"
$vNetPrefix="192.168.0.0/16"
$VMSize="Standard_A2_v2"
$computername="SERVER01"
$VMName="SERVER01"
$sku="2016-Datacenter"


# CREATE INFRASTRUCTURE

# Create Resource Group:

New-AzureRmResourceGroup -Name $rgn -Location $location


# Create Storage Account to Hold VMs:

$storageAcctemp = New-AzureRmStorageAccount -ResourceGroupName $rgn `
    -Location $location -Name $storagename `
    -Kind "Storage" -SkuName $storagesku


# Create Subnets:

$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name $subnet1name `
    -AddressPrefix $subnet1addressprefix
$subnet2 = New-AzureRmVirtualNetworkSubnetConfig -Name $subnet2name `
    -AddressPrefix $subnet2addressprefix


# Create Virtual Network:

$myVnet = New-AzureRmVirtualNetwork -ResourceGroupName $rgn `
    -Location $location -Name $vNetName -AddressPrefix $vNetPrefix `
    -Subnet $subnet1,$subnet2


# Create Public IP Resource (so you can RDP to your VM):

$pip = New-AzureRmPublicIpAddress -Name PublicIP -ResourceGroupName $rgn `
     -AllocationMethod Dynamic -Location $location 


# Create Multiple NICs:

$network1 = $myVnet.Subnets|?{$_.Name -eq $subnet1name}
$myNic1 = New-AzureRmNetworkInterface -ResourceGroupName $rgn `
    -Location $location -Name "NIC1" -SubnetId $network1.Id -PublicIpAddressId $pip.Id

$network2 = $myVnet.Subnets|?{$_.Name -eq $subnet2name}
$myNic2 = New-AzureRmNetworkInterface -ResourceGroupName $rgn `
    -Location $location -Name "NIC2" -SubnetId $network2.Id



# CREATE VIRTUAL MACHINE

# Set VM Credentials (used to login to VM):

$cred = Get-Credential


# Define Your VM Size:

$vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize


# Configure the VM and Select OS:

$vmConfig = Set-AzureRmVMOperatingSystem -VM $vmConfig -Windows -ComputerName $computername `
    -Credential $cred -ProvisionVMAgent -EnableAutoUpdate
$vmConfig = Set-AzureRmVMSourceImage -VM $vmConfig -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" -Skus $sku -Version "latest"


# Attach the NICs:

$vmConfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $myNic1.Id -Primary
$vmConfig = Add-AzureRmVMNetworkInterface -VM $vmConfig -Id $myNic2.Id


# Configure Storage for the VM:

$storageAcc = $storageAcctemp

$blobPath = "vhds/WindowsVMosDisk.vhd"
$osDiskUri = $storageAcc.PrimaryEndpoints.Blob.ToString() + $blobPath
$diskName = "windowsvmosdisk"
$vmConfig = Set-AzureRmVMOSDisk -VM $vmConfig -Name $diskName -VhdUri $osDiskUri `
    -CreateOption "fromImage"


# Create the Actual VM:

New-AzureRmVM -VM $vmConfig -ResourceGroupName $rgn -Location $location
