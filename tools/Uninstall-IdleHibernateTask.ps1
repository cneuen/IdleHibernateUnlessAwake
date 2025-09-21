param([string]$TaskName = "IdleHibernateUnlessAwake")

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  Write-Host "Tâche '$TaskName' supprimée."
} else {
  Write-Host "Tâche '$TaskName' introuvable."
}
