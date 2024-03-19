# Database-Backup-Script-For-Azure-Storage
This PowerShell script is designed to automate the backup process for databases and store them in Azure Storage. It compresses .bak files into .zip files using WinRAR and transfers them to the cloud storage location.

**Usage**

   1. **Set Configuration:**
      - Modify the `$sourcePath`, `$compressionFolder`, and `$cloudBasePath` variables to match your local backup path, compression folder, and Azure Storage path, respectively.
      - Update the `$username` and `$password` variables with your Azure Storage credentials.
      - Adjust other parameters like `$maxRetryAttemptsVerification`, `$retryIntervalSeconds`, `$maxDaysToRetainCloud`, `$weeklymonthlyremove`, and email settings as needed.

   2. **Run the Script:**
      - Execute the script in PowerShell to initiate the backup process.

   3. **Review Logs:**
      - Check the log files in the specified `$logDirectory` to monitor the backup progress and any errors encountered.

3. **Important Notes**

   - Ensure WinRAR is installed and update the `$winrarPath` variable with the correct path.
   - Verify the paths for daily, weekly, and monthly backups in Azure Storage and update accordingly.
   - Use a secure method to handle sensitive information such as passwords and email credentials.

4. **Script Workflow Overview**

   1. **Compression Phase:**
      - Locate .bak files in the source path and compress them into .zip files using WinRAR.
      - Check for existing .zip files to avoid redundant compression.

   2. **Transfer to Cloud Storage:**
      - Map a drive to Azure Storage using the specified credentials.
      - Copy the compressed .zip files to the designated folders in Azure Storage based on the backup frequency (daily, weekly, or monthly).

   3. **Backup Verification:**
      - Verify the successful transfer of files to Azure Storage and log any discrepancies or failures.

   4. **Email Notification:**
      - Send an email notification to specified recipients upon completion of the backup process, including details of the backed-up files.

   5. **Cleanup and Maintenance:**
      - Remove older backups from Azure Storage based on the retention policies set in the script.

5. **Example Email Notification**

Upon successful completion of the backup process, an email notification will be sent to the specified recipients. The email includes information about the backup status and the number of files transferred.
