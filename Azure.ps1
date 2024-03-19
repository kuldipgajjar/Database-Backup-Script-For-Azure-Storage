# Define the source path for .bak files
$sourcePath = "D:\Backup"

# Define the local compression folder
$compressionFolder = "D:\Backup\Zip"

# Define the destination path for .zip files on cloud storage
$cloudBasePath = "\\backuptest22.file.core.windows.net\backupdata\Backup\Database\Daily" # Replace with your actual azure storage path
$currentDateFolder = Get-Date -Format "yyyyMMdd"
$hostnameFolder = $env:COMPUTERNAME

# Define the username and password
$username = "" # Replace with your actual Username
$password = ""  # Replace with your actual password

# Maximum number of retry attempts for verification
$maxRetryAttemptsVerification = 3
$retryCountVerification = 0
$retryIntervalSeconds = 15  # Adjust this as needed

# Get the current date in yyyy-MM-dd format for the log file name
$logDate = Get-Date -Format "yyyy-MM-dd"

# Define the log directory
$logDirectory = "D:\Backup\Logs"

# Ensure the log directory exists if it doesn't
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory
}

# Define the log file path
$logFilePath = Join-Path -Path $logDirectory -ChildPath "$logDate.txt"

# Function to write log entries in the desired format
function Write-LogEntry {
    param (
        [string] $message,
        [string] $logFile
    )

    $logEntry = "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $message
    Write-Host $logEntry
    if ($logFile) {
        $logEntry | Out-File -Append -FilePath $logFile
    }
}

do {
    # Reset variables for each attempt
    $retryCountVerification++
    $verificationFailed = $false

    # Create the local compression folder if it doesn't exist
    if (-not (Test-Path -Path $compressionFolder)) {
        New-Item -ItemType Directory -Path $compressionFolder | Out-Null
    }

        Write-LogEntry "------------File Compression started------------" $logFilePath
	
    # Define the path to the WinRAR executable
    $winrarPath = "D:\bkscript\WinRAR\WinRAR.exe"  # Replace with the actual path

    # Compress .bak files into self-extracting .exe using WinRAR
	foreach ($backupFile in Get-ChildItem -Path $sourcePath -Filter *.bak) {
    $zipFilePath = Join-Path $compressionFolder "$($backupFile.BaseName).zip"

    # Check if the .zip file already exists, skip compression if it does
    if (-not (Test-Path -Path $zipFilePath)) {
        # Use WinRAR to create a ZIP archive without displaying the dialog box
        $process = Start-Process -FilePath $winrarPath -ArgumentList "a -ibck `"$zipFilePath`" `"$($backupFile.FullName)`"" -PassThru
        $process.WaitForExit()
        Write-LogEntry "Compressed .bak file: $zipFilePath" $logFilePath
		}
	}

    Write-LogEntry "------------File Compression finished------------" $logFilePath

    # Create a PSDrive using the mapped drive letter, username, and password
    $psDrive = Get-PSDrive -Name "V" -ErrorAction SilentlyContinue

    if (-not $psDrive) {
        New-PSDrive -Name "V" -PSProvider FileSystem -Root $cloudBasePath -Credential (New-Object System.Management.Automation.PSCredential -ArgumentList $username, (ConvertTo-SecureString -String $password -AsPlainText -Force)) -Persist
    }

    # Combine the base path with the date and hostname to get the full path
    $currentDateFolderPath = Join-Path "V:\" $currentDateFolder
    $hostnameFolderPath = Join-Path $currentDateFolderPath $hostnameFolder

    # Create the current date folder if it doesn't exist
    if (-not (Test-Path -Path $currentDateFolderPath)) {
        New-Item -ItemType Directory -Path $currentDateFolderPath | Out-Null
    }

    # Create the hostname folder if it doesn't exist
    if (-not (Test-Path -Path $hostnameFolderPath)) {
        New-Item -ItemType Directory -Path $hostnameFolderPath | Out-Null
    }

    Write-LogEntry "------------Daily backup started------------" $logFilePath

    function Transfer-ZipFile {
        param (
            [string]$zipFilePath,
            [string]$cloudFolderPath
        )

        # Construct the destination path in cloud storage
        $cloudZipPath = Join-Path -Path $cloudFolderPath -ChildPath (Join-Path -Path $hostnameFolder -ChildPath ([System.IO.Path]::GetFileName($zipFilePath)))

        # Check if the .zip file already exists in the cloud storage, skip transfer if it does
        if (-not (Test-Path -Path $cloudZipPath)) {
            # Copy the .zip file to the cloud storage path
            $destinationFileName = [System.IO.Path]::GetFileName($zipFilePath)
            Copy-Item -Path $zipFilePath -Destination $cloudZipPath -Credential $Credential
            Write-LogEntry "Transferred .zip file: $destinationFileName" $logFilePath
        }
    }

    # Transfer .zip files to cloud storage
    $zipFiles = Get-ChildItem -Path $compressionFolder -Filter *.zip

    foreach ($zipFile in $zipFiles) {
        Transfer-ZipFile -zipFilePath $zipFile.FullName -cloudFolderPath $currentDateFolderPath
    }

    Write-LogEntry "------------Daily backup finished------------" $logFilePath

    # Maximum number of days to retain cloud backups
    $maxDaysToRetainCloud = 6  # Adjust as needed
	$weeklymonthlyremove = 90 # Adjust as needed

    # Define the paths for storing backups on Sunday
    $dailyBackupPath = "\\backuptest22.file.core.windows.net\backupdata\Backup\Database\Daily"
    $weeklyBackupPath = "\\backuptest22.file.core.windows.net\backupdata\Backup\Database\Weekly"
	$monthlyBackupPath = "\\backuptest22.file.core.windows.net\backupdata\Backup\Database\Monthly"

    # Verification: Check if all local .bak files have corresponding .zip files in the cloud
    $localBakFiles = Get-ChildItem -Path $sourcePath -Filter *.bak
    $cloudZipFiles = Get-ChildItem -Path $hostnameFolderPath -Filter *.zip

    # Count the number of .bak files and .zip files
    $numberOfBakFiles = $localBakFiles.Count
    $numberOfZipFiles = $cloudZipFiles.Count

    # Check if there are local .bak files
    if ($numberOfBakFiles -eq 0) {
        Write-LogEntry "Verification failed: No local .bak files found." $logFilePath
        $verificationFailed = $true
    } else {
        # Check if there are no local .zip files
        if ($numberOfZipFiles -eq 0) {
            Write-LogEntry "Verification failed: No local .zip files found." $logFilePath
            $verificationFailed = $true
        } else {
            # Compare .bak files to .zip files
            if ($numberOfBakFiles -eq $numberOfZipFiles) {
				
				Write-LogEntry "Verification successful: The total number of files matches between the local folder and cloud storage." $logFilePath
               
                Write-LogEntry "------------Total no. of compressed file------------" $logFilePath

                # Log the count of .bak and .zip files
                Write-LogEntry "Total .bak files: $numberOfBakFiles" $logFilePath
                Write-LogEntry "Total .zip files: $numberOfZipFiles" $logFilePath

                # Remove older cloud backups
                $cutOffDateCloud = (Get-Date).AddDays(-$maxDaysToRetainCloud)
                $oldCloudBackupFolders = Get-ChildItem -Path $cloudBasePath | Where-Object { $_.PSIsContainer -and $_.Name -lt $cutOffDateCloud.ToString("yyyyMMdd") }
                $oldCloudBackupFolders | ForEach-Object {
                    $folderPath = Join-Path -Path $cloudBasePath -ChildPath $_.Name
                    Remove-Item -Path $folderPath -Recurse -Force
                    Write-LogEntry "Removed older backup folder: $folderPath" $logFilePath
					
				 }
            } else {
                $verificationFailed = $true
                Write-LogEntry "Verification failed: The total number of files does not match between the local folder and cloud storage." $logFilePath
            }
        }
    }
} while ($verificationFailed -and $retryCountVerification -lt $maxRetryAttemptsVerification)

		# Wait for 1 minute (60 seconds)
		Start-Sleep -Seconds 30

	# Check if today is Sunday
	if ((Get-Date).DayOfWeek -eq 'Sunday') {
    Write-LogEntry "------------Weekly backup started------------" $logFilePath
    $copiedFiles7 = Copy-Item -Path $currentDateFolderPath -Destination $weeklyBackupPath -Recurse -Force -Credential $Credential -PassThru
    # Filter only files (exclude directories)
    $copiedFiles7 = $copiedFiles7 | Where-Object { -not $_.PSIsContainer }
    
    # Log each transferred file
    foreach ($copiedFile77 in $copiedFiles7) {
        Write-LogEntry "Transferred .zip file: $($copiedFile77.Name)" $logFilePath
    }
    Write-LogEntry "------------Weekly backup finished------------" $logFilePath

    # Remove older cloud backups
    $cutOffDateCloud1 = (Get-Date).AddDays(-$weeklymonthlyremove)
    $oldCloudBackupFolders1 = Get-ChildItem -Path $weeklyBackupPath | Where-Object { $_.PSIsContainer -and $_.Name -lt $cutOffDateCloud1.ToString("yyyyMMdd") }
    $oldCloudBackupFolders1 | ForEach-Object {
    $folderPath1 = Join-Path -Path $weeklyBackupPath -ChildPath $_.Name
    Remove-Item -Path $folderPath1 -Recurse -Force
    Write-LogEntry "Removed Weekly older backup folder: $folderPath1" $logFilePath
    }
}
		
		Start-Sleep -Seconds 30
	

	# Check if today is the last day of the month
	if ((Get-Date).AddDays(1).Month -ne (Get-Date).Month) {
		
	# Determine the source path of the last daily backup
	$lastDailyBackupPath = Get-ChildItem -Path $dailyBackupPath -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	if ($lastDailyBackupPath -eq $null) {
			Write-LogEntry "Monthly backup will not be performed." $logFilePath
	} 
	else {
		Write-LogEntry "------------Monthly backup started------------" $logFilePath
		
            $copiedFiles30 = Copy-Item -Path $currentDateFolderPath -Destination $monthlyBackupPath -Recurse -Force -Credential $Credential -PassThru
            # Filter only files (exclude directories)
            $copiedFiles30 = $copiedFiles30 | Where-Object { -not $_.PSIsContainer }
            # Log each transferred file
            foreach ($copiedFile300 in $copiedFiles30) {
            Write-LogEntry "Transferred .zip file: $($copiedFile300.Name)" $logFilePath
         }
		Write-LogEntry "------------Monthly backup finished------------" $logFilePath
		
		# Remove older cloud backups
         $cutOffDateCloud2 = (Get-Date).AddDays(-$weeklymonthlyremove)
         $oldCloudBackupFolders2 = Get-ChildItem -Path $monthlyBackupPath | Where-Object { $_.PSIsContainer -and $_.Name -lt $cutOffDateCloud2.ToString("yyyyMMdd") }
         $oldCloudBackupFolders2 | ForEach-Object {
         $folderPath2 = Join-Path -Path $monthlyBackupPath -ChildPath $_.Name
         Remove-Item -Path $folderPath2 -Recurse -Force
         Write-LogEntry "Removed Monthly older backup folder: $folderPath2" $logFilePath
					
				}
			}
		}

# Send an email using SMTP
$recipients = @("example@gmail.com","hello@gmail.com") #which user want mail regarding above content you mention here
$smtpSenderMailAdd = "youremail@gmail.com"  # Replace with your Gmail email address
$smtpPassword = "bgbu dkeo xict aowj"  # Replace with your Gmail App Password (Search on google and generate from your account)
$smtpIp = "smtp.gmail.com"
$smtpPortNo = 587

# Initialize the mail body with the start message
$mailBody = "Server: $hostnameFolder`r`n`r`n"

# Check if Daily Backup performed
if ($zipFiles.Count -gt 0) {
    $mailBody += "Following Database Backup compressed files copied as Daily Backup.`r`n"
    # Add the backup details to the mail body
    $totalFiles = 0
    foreach ($zipFile in $zipFiles) {
        $mailBody += "File: $($zipFile.Name) copied`r`n"
        $totalFiles++
    }
    $mailBody += "`r`nTotal files: $totalFiles`r`n"
} else {
    $mailBody += "Daily backup will not be performed.`r`n"
}

# Check if Weekly Backup performed
if ((Get-Date).DayOfWeek -eq 'Sunday') {
    if ($copiedFiles7 -ne $null) {
        $mailBody += "`r`nFollowing Database Backup compressed files copied as Weekly Backup.`r`n"
        $totalFiles = 0
        foreach ($copiedFile77 in $copiedFiles7) {
            $mailBody += "File: $($copiedFile77.Name) copied`r`n"
            $totalFiles++
        }
        $mailBody += "`r`nTotal files: $totalFiles`r`n"
    } else {
        $mailBody += "`r`nWeekly backup will not be performed.`r`n"
    }
}

# Check if Monthly Backup performed
if ((Get-Date).AddDays(1).Month -ne (Get-Date).Month) {
    if ($copiedFiles30 -ne $null) {
        $mailBody += "`r`nFollowing Database Backup compressed files copied as Monthly Backup.`r`n"
        $totalFiles = 0
        foreach ($copiedFile300 in $copiedFiles30) {
            $mailBody += "File: $($copiedFile300.Name) copied`r`n"
            $totalFiles++
        }
        $mailBody += "`r`nTotal files: $totalFiles`r`n"
    } else {
        $mailBody += "`r`nMonthly backup will not be performed.`r`n"
    }
}

# Create the email message
$mailParams = @{
    From         = $smtpSenderMailAdd
    To           = $recipients  # Use the array of recipient email addresses
    Subject      = "Backup Completed for $hostnameFolder"
    Body         = $mailBody
    SmtpServer   = $smtpIp
    Port         = $smtpPortNo
    Credential   = New-Object System.Management.Automation.PSCredential($smtpSenderMailAdd, (ConvertTo-SecureString $smtpPassword -AsPlainText -Force))
    UseSsl       = $true
}

# Send the email
Send-MailMessage @mailParams

Write-LogEntry "Mail sent to $($recipients -join ', ')" $logFilePath

# Remove the mapped drive after use
Remove-PSDrive -Name "V"

# Clean up local compressed files
Remove-Item -Path $compressionFolder -Recurse -Force