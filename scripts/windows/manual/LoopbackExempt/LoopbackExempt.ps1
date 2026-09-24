[CmdletBinding()]
param()

# 用 HashSet 存储已免除列表，O(1) 查找，大小写不敏感。
$exemptedSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

# 精确解析 CheckNetIsolation 输出的 Name 字段，避免误匹配。
CheckNetIsolation LoopbackExempt -s | ForEach-Object {
    if ($_ -match '(?:Name|名称):\s*([^\s,\]]+)') {
        [void]$exemptedSet.Add($Matches[1])
    }
}

$added = 0
$skipped = 0
$failed = 0

Get-AppxPackage | ForEach-Object {
    $pfn = $_.PackageFamilyName

    if ([string]::IsNullOrWhiteSpace($pfn)) {
        return
    }

    if ($exemptedSet.Contains($pfn)) {
        Write-Verbose "已存在: $pfn"
        $skipped++
    }
    else {
        try {
            $result = CheckNetIsolation LoopbackExempt -a -n="$pfn" 2>&1

            # CheckNetIsolation 是原生命令，失败时不会自动触发 catch。
            if ($LASTEXITCODE -ne 0) {
                throw (($result | Out-String).Trim())
            }

            Write-Host "✔ 已添加: $pfn" -ForegroundColor Green
            $added++
        }
        catch {
            Write-Warning "✘ 失败: $pfn — $($_.Exception.Message)"
            $failed++
        }
    }
}

Write-Host "完成 | 新增: $added  已跳过: $skipped  失败: $failed" -ForegroundColor Cyan
