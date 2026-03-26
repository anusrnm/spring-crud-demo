#Requires -Version 7.0
<#
.SYNOPSIS
    POST sample products to the running Spring CRUD Demo API in parallel.

.PARAMETER BaseUrl
    Base URL of the running application.  Defaults to http://localhost:8080.

.PARAMETER Count
    Number of products to create.  Defaults to 100.

.PARAMETER Concurrency
    Number of simultaneous HTTP requests.  Defaults to 20.

.EXAMPLE
    .\seed-products.ps1
    .\seed-products.ps1 -BaseUrl http://localhost:8080 -Count 200 -Concurrency 30
#>
param(
    [string] $BaseUrl     = 'http://localhost:8080',
    [int]    $Count       = 100,
    [int]    $Concurrency = 20
)

$categories = @(
    @{ Prefix = 'Laptop';      Desc = 'High-performance laptop';         Min = 499.99;  Max = 2499.99 }
    @{ Prefix = 'Monitor';     Desc = 'Full-HD widescreen monitor';      Min = 149.99;  Max = 799.99  }
    @{ Prefix = 'Keyboard';    Desc = 'Mechanical RGB keyboard';         Min = 39.99;   Max = 199.99  }
    @{ Prefix = 'Mouse';       Desc = 'Wireless ergonomic mouse';        Min = 19.99;   Max = 129.99  }
    @{ Prefix = 'Headset';     Desc = 'Noise-cancelling headset';        Min = 49.99;   Max = 349.99  }
    @{ Prefix = 'Webcam';      Desc = '4K streaming webcam';             Min = 59.99;   Max = 249.99  }
    @{ Prefix = 'SSD';         Desc = 'NVMe solid-state drive';          Min = 59.99;   Max = 399.99  }
    @{ Prefix = 'RAM';         Desc = 'DDR5 memory module';              Min = 29.99;   Max = 179.99  }
    @{ Prefix = 'GPU';         Desc = 'Discrete graphics card';          Min = 199.99;  Max = 1299.99 }
    @{ Prefix = 'CPU';         Desc = 'Multi-core desktop processor';    Min = 99.99;   Max = 699.99  }
)

$url     = "$BaseUrl/api/products"
$headers = @{ 'Content-Type' = 'application/json' }

# -----------------------------------------------------------------
# 1. Pre-build all payloads serially (fast, no I/O)
# -----------------------------------------------------------------
$payloads = 1..$Count | ForEach-Object {
    $i   = $_
    $cat = $categories[($i - 1) % $categories.Count]
    $price = [math]::Round(
        $cat.Min + (Get-Random -Minimum 0 -Maximum 10000) / 10000.0 * ($cat.Max - $cat.Min), 2)
    $qty = Get-Random -Minimum 0 -Maximum 500
    [PSCustomObject]@{
        Name = "$($cat.Prefix) Model-$i"
        Json = ([ordered]@{
            name        = "$($cat.Prefix) Model-$i"
            description = "$($cat.Desc) - unit $i"
            price       = $price
            quantity    = $qty
        } | ConvertTo-Json)
    }
}

# -----------------------------------------------------------------
# 2. Fire all requests in parallel - $Concurrency at a time
# -----------------------------------------------------------------
Write-Host "Seeding $Count products to $url  [concurrency=$Concurrency] ..."

$results = $payloads | ForEach-Object -ThrottleLimit $Concurrency -Parallel {
    $item    = $_
    $headers = @{ 'Content-Type' = 'application/json' }
    try {
        $r = Invoke-RestMethod -Uri $using:url -Method Post -Headers $headers `
                               -Body $item.Json -ErrorAction Stop
        [PSCustomObject]@{ OK = $true;  Name = $r.name; Id = $r.id; Price = $r.price }
    } catch {
        [PSCustomObject]@{ OK = $false; Name = $item.Name; Error = $_.Exception.Message }
    }
}

# -----------------------------------------------------------------
# 3. Report results
# -----------------------------------------------------------------
$ok     = 0
$failed = 0
$results | Sort-Object Name | ForEach-Object {
    if ($_.OK) {
        $ok++
        Write-Host "  [OK] $($_.Name)  id=$($_.Id)  price=$($_.Price)"
    } else {
        $failed++
        Write-Warning "  [FAIL] $($_.Name) - $($_.Error)"
    }
}

Write-Host ""
Write-Host "Done. Created: $ok  Failed: $failed"
