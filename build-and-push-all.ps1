$ErrorActionPreference = "Stop"
$baseDir = "c:\Users\Duc Thinh\Documents\Học tập\Đồ án chuyên ngành\robot-shop-devops-lab"

$services = @(
    @{ name = "dispatch";  dir = "dispatch";  image = "ducthinhahihi/rs-dispatch:v1.0" },
    @{ name = "web";       dir = "web";       image = "ducthinhahihi/rs-web:v1.0" },
    @{ name = "mongo";     dir = "mongo";     image = "ducthinhahihi/rs-mongodb:v1.0" },
    @{ name = "mysql";     dir = "mysql";     image = "ducthinhahihi/rs-mysql:v1.0" }
)

Write-Host "Bat dau build va push 4 service con lai len Docker Hub (ducthinhahihi)..." -ForegroundColor Cyan

foreach ($s in $services) {
    Write-Host "`n>>> [1/2] Dang build $($s.name) ($($s.image))..." -ForegroundColor Yellow
    $dirPath = Join-Path $baseDir $s.dir
    Set-Location $dirPath
    
    docker build -t $s.image .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Loi build tai $($s.name)!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ">>> [2/2] Dang push $($s.name) len Docker Hub..." -ForegroundColor Yellow
    docker push $s.image
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Loi push tai $($s.name)!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "=== HOAN THANH: $($s.name) ===" -ForegroundColor Green
}

Set-Location $baseDir
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "TAT CA 10/10 SERVICES DA CO MAT TREN DOCKER HUB!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
