$log = Join-Path $env:TEMP 'IdleAwakeProbe.txt'
function Write-Log($m){ ("{0} | {1}" -f (Get-Date -Format o), $m) | Out-File $log -Append -Encoding UTF8 }

Write-Log "Task started; user=$(whoami)"
try{
  $awake=$false; $mode=$null; $keep=$null; $src=@()

  $reg='HKCU:\Software\Microsoft\PowerToys\Awake'
  if(Test-Path $reg){
    $p=Get-ItemProperty $reg -ErrorAction SilentlyContinue
    if($p){
      if($p.PSObject.Properties.Name -contains 'Mode'){ $mode=$p.Mode }
      if($p.PSObject.Properties.Name -contains 'Enabled'){ $keep=[bool]$p.Enabled }
      $src+='reg'
    }
  }

  $json = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\Awake\settings.json'
  if(Test-Path $json){
    try{
      $cfg=Get-Content $json -Raw | ConvertFrom-Json
      if($null -eq $mode){ $mode=$cfg.properties.mode }
      if($null -eq $keep){ $keep=$cfg.properties.keepAwake }
      $src+='json'
    }catch{}
  }

  try{
    $req = (powercfg /requests) -join "`n"
    Write-Log ("powercfgRequestsMatch=" + ($req -match 'PowerToys'))
    if(-not $awake -and $req -match 'PowerToys'){ $awake=$true; $src+='requests' }
  }catch{}

  Write-Log ("sources=" + ($src -join '+') + " | mode=" + $mode + " | keep=" + $keep + " | Awake=" + $awake)
  if($awake){ exit 1 } else { exit 0 }
}catch{
  Write-Log ("ERROR: " + $_.Exception.Message); exit 2
}
