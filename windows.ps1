# Stop on any errors
$ErrorActionPreference = "Stop"

$wd = "$env:AZ_BATCH_TASK_WORKING_DIR\batchinsights"
mkdir "$wd"
cd "$wd"

Try
{
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    choco install -y python2
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "Current path: $env:Path"

    Write-Host "Python version:"
    python --version
    pip install psutil python-dateutil applicationinsights==0.11.7 nvidia-ml-py
    Write-Host "Downloading nodestats.py"
    Invoke-WebRequest https://raw.githubusercontent.com/smith1511/batch-insights/gpu/nodestats.py -OutFile nodestats.py

    # Delete if exists
    $exists = Get-ScheduledTask | Where-Object {$_.TaskName -like "batchappinsights" };
    if($exists)
    {
        Write-Host "Scheduled task already exists. Removing it and restarting it";
        Stop-ScheduledTask -TaskName "batchappinsights";
        Unregister-ScheduledTask -Confirm:$false -TaskName "batchappinsights";
    }

    $pythonPath = get-command python | Select-OBject -ExpandProperty Definition
    Write-Host "Resolved python path to $pythonPath"

    Write-Host "Starting App insights background process in $wd"
    $action = New-ScheduledTaskAction -WorkingDirectory $wd -Execute 'Powershell.exe' -Argument "Start-Process $pythonPath -ArgumentList ('.\nodestats.py','$env:AZ_BATCH_POOL_ID', '$env:AZ_BATCH_NODE_ID', '$env:APP_INSIGHTS_INSTRUMENTATION_KEY')  -RedirectStandardOutput .\node-stats.log -RedirectStandardError .\node-stats.err.log -NoNewWindow"
    $principal = New-ScheduledTaskPrincipal -UserID 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest ;
    Register-ScheduledTask -Action $action -Principal $principal -TaskName "batchappinsights" -Force ;
    Start-ScheduledTask -TaskName "batchappinsights";
    Get-ScheduledTask -TaskName "batchappinsights";
}
Finally 
{
    cd ..
}
