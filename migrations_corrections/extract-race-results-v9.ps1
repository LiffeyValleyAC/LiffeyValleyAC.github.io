param(
    [string]$InputRoot = 'C:\LiffeyValleyAC.github.io\_races',
    [string]$ClubMembersPath = 'C:\LiffeyValleyAC.github.io\club_members.txt',
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\outputs\lvac-races-v9.tsv'),
    [int]$StartId = 1000,
    [int]$MaxFiles = 0,
    [string[]]$Files,
    [string]$DateFrom = '',
    [string]$DateTo = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-DateFilterValue {
    param(
        [AllowNull()][string]$Value,
        [Parameter(Mandatory)][string]$ParameterName
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $parsed = [datetime]::MinValue
    $valid = [datetime]::TryParseExact(
        $Value.Trim(),
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )
    if (-not $valid) {
        throw "$ParameterName must use yyyy-MM-dd format: $Value"
    }

    return $parsed.Date
}

function Test-DateInRange {
    param(
        [Parameter(Mandatory)][datetime]$Date,
        [AllowNull()][Nullable[datetime]]$From,
        [AllowNull()][Nullable[datetime]]$To
    )

    if ($null -ne $From -and $Date -lt [datetime]$From) {
        return $false
    }
    if ($null -ne $To -and $Date -gt [datetime]$To) {
        return $false
    }
    return $true
}

$dateFromValue = ConvertTo-DateFilterValue -Value $DateFrom -ParameterName 'DateFrom'
$dateToValue = ConvertTo-DateFilterValue -Value $DateTo -ParameterName 'DateTo'
if ($null -ne $dateFromValue -and $null -ne $dateToValue -and $dateFromValue -gt $dateToValue) {
    throw "DateFrom cannot be later than DateTo: $DateFrom > $DateTo"
}
$dateFilterActive = ($null -ne $dateFromValue -or $null -ne $dateToValue)

function Read-Utf8Text {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function Write-Utf8Text {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Text
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Repair-Mojibake {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $text = $Value
    if ($text -match '[\u00C3\u00C2\u00E2\u00F0]') {
        try {
            $bytes = [System.Text.Encoding]::GetEncoding(1252).GetBytes($text)
            $candidate = [System.Text.Encoding]::UTF8.GetString($bytes)
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $text = $candidate
            }
        } catch {
        }
    }

    $text = $text -replace "[\u2019\u2018\u00B4]", "'"
    $text = $text -replace "[\u201C\u201D]", '"'
    $text = $text -replace 'ðŸ¥‡', '🥇'
    $text = $text -replace 'ðŸ¥ˆ', '🥈'
    $text = $text -replace 'ðŸ¥‰', '🥉'
    $text = $text -replace '\s+', ' '
    return $text.Trim()
}

function Remove-Diacritics {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $normalized = $Value.Normalize([System.Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($category -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($ch)
        }
    }

    return $builder.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}

function Normalize-Name {
    param(
        [AllowNull()][string]$Value,
        [ref]$Changed
    )

    if ($null -ne $Changed) {
        $Changed.Value = $false
    }
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $original = $Value
    $text = Repair-Mojibake $Value
    $text = Remove-Diacritics $text
    $text = [regex]::Replace($text, '\s*\(\d+\)\s*$', '')
    $text = $text -replace '\s+', ' '
    $text = $text.Trim()

    $textInfo = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo
    $text = $textInfo.ToTitleCase($text.ToLowerInvariant())
    $text = [regex]::Replace($text, "([A-Za-z])'([A-Za-z])", {
            param($m)
            return ($m.Groups[1].Value + "'" + $m.Groups[2].Value.ToUpperInvariant())
        })
    $text = [regex]::Replace($text, '\bMc([A-Za-z])', {
            param($m)
            return ('Mc' + $m.Groups[1].Value.ToUpperInvariant())
        })

    if ($null -ne $Changed) {
        $baseline = Remove-Diacritics (Repair-Mojibake $original)
        $baseline = [regex]::Replace($baseline, '\s+', ' ').Trim()
        $Changed.Value = ($baseline -ne $text)
    }
    return $text
}

function Get-NameKey {
    param([AllowNull()][string]$Value)
    $changed = $false
    return (Normalize-Name -Value $Value -Changed ([ref]$changed)).ToUpperInvariant()
}

function Unquote-Value {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    $text = $Value.Trim()
    if (($text.StartsWith('"') -and $text.EndsWith('"')) -or ($text.StartsWith("'") -and $text.EndsWith("'"))) {
        if ($text.Length -ge 2) {
            $text = $text.Substring(1, $text.Length - 2)
        }
    }
    return $text.Trim()
}

function Split-KeyValue {
    param([Parameter(Mandatory)][string]$Line)

    $idx = $Line.IndexOf(':')
    if ($idx -lt 0) {
        return @($Line.Trim(), '')
    }

    $key = $Line.Substring(0, $idx).Trim()
    $value = Unquote-Value $Line.Substring($idx + 1)
    return @($key, $value)
}

function Get-OptionalProperty {
    param(
        [Parameter(Mandatory)][psobject]$Object,
        [Parameter(Mandatory)][string]$Name
    )

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) {
        return ''
    }

    return [string]$prop.Value
}

function Convert-Gender {
    param([AllowNull()][string]$Value)

    $text = (Repair-Mojibake $Value).Trim().ToUpperInvariant()
    if ($text -match '^(W|F|WOMEN|FEMALE)$') { return 'Women' }
    if ($text -match '^(M|MEN|MALE)$') { return 'Men' }
    return ''
}

function Load-ClubMembers {
    param([Parameter(Mandatory)][string]$Path)

    $members = @{}
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.UTF8Encoding]::new($false))
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -match '^\d{1,2}:\d{2}\s+\d{2}/\d{2}/\d{4}$') {
            continue
        }
        if ($line -match '^\s*NAME\s+GENDER\s*$') {
            continue
        }

        $parts = $line -split "`t"
        if ($parts.Count -lt 2) {
            $parts = $line -split '\s{2,}'
        }
        if ($parts.Count -lt 2) {
            continue
        }

        $changed = $false
        $name = Normalize-Name -Value $parts[0] -Changed ([ref]$changed)
        $gender = Convert-Gender $parts[1]
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($gender)) {
            continue
        }

        $key = Get-NameKey $name
        if (-not $members.ContainsKey($key)) {
            $members[$key] = [pscustomobject]@{
                Name = $name
                Gender = $gender
            }
        }
    }

    return $members
}

function Normalize-Note {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $text = Repair-Mojibake $Value
    $text = [regex]::Replace($text, '(?i)\bPersonal Best\b', 'PB')
    $text = [regex]::Replace($text, '(?i)\bSeason Best\b', 'SB')
    $text = [regex]::Replace($text, '(?i)<br\s*/?>', ' | ')
    $text = [regex]::Replace($text, '[\uFFFD\p{Cc}]', ' ')
    $text = $text -replace '\s+', ' '
    return $text.Trim()
}

function Normalize-Place {
    param(
        [AllowNull()][string]$Value,
        [ref]$NeedsCheck
    )

    if ($null -ne $NeedsCheck) {
        $NeedsCheck.Value = $false
    }
    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($null -ne $NeedsCheck) { $NeedsCheck.Value = $true }
        return ''
    }

    $text = Repair-Mojibake $Value
    $text = $text -replace '[\u00B0\u00BA]', ''
    if ($text -match '^\d+$') {
        return $text
    }

    $gold = [System.Char]::ConvertFromUtf32(0x1F947)
    $silver = [System.Char]::ConvertFromUtf32(0x1F948)
    $bronze = [System.Char]::ConvertFromUtf32(0x1F949)

    if ($text -eq $gold -or $text -match '^(1st|1st place|first)$') { return '1' }
    if ($text -eq $silver -or $text -match '^(2nd|second)$') { return '2' }
    if ($text -eq $bronze -or $text -match '^(3rd|third)$') { return '3' }

    if ($null -ne $NeedsCheck) {
        $NeedsCheck.Value = $true
    }
    return $text
}

function Test-IgnoredResult {
    param([Parameter(Mandatory)][psobject]$Result)

    foreach ($prop in $Result.PSObject.Properties) {
        $value = Repair-Mojibake ([string]$prop.Value)
        if ($value -match '(?i)\bDNF\b|\bTBC\b') {
            return $true
        }
        if ($prop.Name -match '^(time|finish_time|actual_time)$' -and $value -match '(?i)^"?\s*ND\s*"?$') {
            return $true
        }
    }

    return $false
}

function Convert-SecondsToTimestamp {
    param([Parameter(Mandatory)][double]$Seconds)

    $centis = [math]::Round($Seconds * 100.0, 0, [System.MidpointRounding]::AwayFromZero)
    if ($centis -lt 0) {
        $centis = 0
    }

    $hours = [int][math]::Floor($centis / 360000)
    $centis -= ($hours * 360000)
    $minutes = [int][math]::Floor($centis / 6000)
    $centis -= ($minutes * 6000)
    $secondsWhole = [int][math]::Floor($centis / 100)
    $hundredths = [int]($centis % 100)

    return ('{0:00}:{1:00}:{2:00}.{3:00}' -f $hours, $minutes, $secondsWhole, $hundredths)
}

function Normalize-TimeText {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $text = Repair-Mojibake $Value
    $text = [regex]::Replace($text, '\[[^\]]*\]', ' ')
    $text = $text -replace '[",]', ' '
    $text = $text -replace '\s+', ' '
    return $text.Trim()
}

function Format-DistanceText {
    param([double]$Distance)

    $text = $Distance.ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
    if ($text.Contains('.')) {
        $text = $text.TrimEnd('0').TrimEnd('.')
    }
    return $text
}

function Remove-ParentheticalText {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $text = $Value
    for ($i = 0; $i -lt 10; $i++) {
        $updated = [regex]::Replace($text, '\([^()]*\)', ' ')
        if ($updated -eq $text) {
            break
        }
        $text = $updated
    }

    return ($text -replace '\s+', ' ').Trim()
}

function Get-DistanceAnnotation {
    param([AllowNull()][string]$Distance)

    if ([string]::IsNullOrWhiteSpace($Distance)) {
        return ''
    }

    $text = Repair-Mojibake $Distance
    $start = $text.IndexOf('(')
    $end = $text.LastIndexOf(')')
    if ($start -lt 0 -or $end -le $start) {
        return ''
    }

    return Normalize-Note $text.Substring($start + 1, $end - $start - 1)
}

function Get-DistanceFromText {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $normalized = (Remove-ParentheticalText (Repair-Mojibake $Value)).ToLowerInvariant()
    if ($normalized -match 'half\s*marathon') { return '21.1' }
    if ($normalized -match '\bmarathon\b') { return '42.2' }

    if ($normalized -match '(?<value>\d+(?:\.\d+)?)\s*k(?:m)?\b') {
        return Format-DistanceText ([double]::Parse($Matches.value, [System.Globalization.CultureInfo]::InvariantCulture))
    }

    if ($normalized -match '(?<value>\d{3,5})\s*m\b' -or $normalized -match '(?<value>\d{3,5})m\b') {
        return Format-DistanceText ([math]::Round(([double]$Matches.value / 1000.0), 2))
    }

    if ($normalized -match '(?<value>\d{1,2})\s*miles?\b' -or $normalized -match '(?<value>\d{1,2})miles?\b' -or $normalized -match '(?<value>\d{1,2})\s*m\b') {
        return Format-DistanceText ([math]::Round(([double]$Matches.value * 1.60934), 1))
    }

    return ''
}

function Get-DistanceFromRaceSpec {
    param(
        [AllowNull()][string]$Distance,
        [AllowNull()][string]$Gender,
        [AllowNull()][string]$Category
    )

    if ([string]::IsNullOrWhiteSpace($Distance)) {
        return ''
    }

    $normalized = (Remove-ParentheticalText (Repair-Mojibake $Distance)).ToLowerInvariant()
    $hasGenderRules = ($normalized -match '\bwomen\b|\bmen\b')
    if (-not $hasGenderRules) {
        return Get-DistanceFromText $Distance
    }

    $segments = @($normalized -split '\s*,\s*' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $categoryText = (Repair-Mojibake $Category).ToUpperInvariant()
    $categoryAge = $null
    if ($categoryText -match '\bM(?<age>\d{2})\b') {
        $categoryAge = [int]$Matches.age
    }

    if ($Gender -eq 'Women') {
        foreach ($segment in $segments) {
            if ($segment -match '\bwomen\b') {
                $distanceText = Get-DistanceFromText $segment
                if (-not [string]::IsNullOrWhiteSpace($distanceText)) { return $distanceText }
            }
        }
    }

    if ($Gender -eq 'Men') {
        if ($null -ne $categoryAge) {
            $ageMatches = foreach ($segment in $segments) {
                if ($segment -match '\bmen\b' -and $segment -match '\bm(?<age>\d{2})\b') {
                    [pscustomobject]@{
                        Age = [int]$Matches.age
                        Text = $segment
                    }
                }
            }

            foreach ($match in @($ageMatches | Sort-Object Age -Descending)) {
                if ($categoryAge -ge $match.Age) {
                    $distanceText = Get-DistanceFromText $match.Text
                    if (-not [string]::IsNullOrWhiteSpace($distanceText)) { return $distanceText }
                }
            }
        }

        foreach ($segment in $segments) {
            if ($segment -match '\bmen\b' -and $segment -notmatch '\bm\d{2}\b') {
                $distanceText = Get-DistanceFromText $segment
                if (-not [string]::IsNullOrWhiteSpace($distanceText)) { return $distanceText }
            }
        }
    }

    return Get-DistanceFromText $Distance
}

function Get-DistanceKm {
    param(
        [AllowNull()][string]$Title,
        [AllowNull()][string]$Distance,
        [AllowNull()][string]$Category,
        [AllowNull()][string]$Gender,
        [AllowNull()][string]$Note,
        [AllowNull()][string]$ResultDistance
    )

    foreach ($source in @($ResultDistance, $Note)) {
        $distanceText = Get-DistanceFromText $source
        if (-not [string]::IsNullOrWhiteSpace($distanceText)) {
            return $distanceText
        }
    }

    $distanceFromSpec = Get-DistanceFromRaceSpec -Distance $Distance -Gender $Gender -Category $Category
    if (-not [string]::IsNullOrWhiteSpace($distanceFromSpec)) {
        return $distanceFromSpec
    }

    foreach ($source in @($Category, $Title)) {
        $distanceText = Get-DistanceFromText $source
        if (-not [string]::IsNullOrWhiteSpace($distanceText)) {
            return $distanceText
        }
    }

    return ''
}

function Get-RaceTimeInfo {
    param(
        [AllowNull()][string]$Value,
        [AllowNull()][string]$Title,
        [AllowNull()][string]$Distance,
        [AllowNull()][string]$Category,
        [AllowNull()][string]$Gender,
        [AllowNull()][string]$Note,
        [AllowNull()][string]$ResultDistance
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{ Seconds = $null; Text = ''; Parsed = $false }
    }

    $raw = Normalize-TimeText $Value
    $normalized = $raw -replace ',', '.'
    $distanceText = Get-DistanceKm -Title $Title -Distance $Distance -Category $Category -Gender $Gender -Note $Note -ResultDistance $ResultDistance
    $distanceKm = $null
    if (-not [string]::IsNullOrWhiteSpace($distanceText)) {
        $distanceKm = [double]::Parse($distanceText, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    if ($normalized -match '^(?<h>\d{1,2})\s*h(?:rs?|ours?)?\s*(?<m>\d{1,2})m\s*(?<s>\d{1,2}(?:\.\d+)?)s$') {
        $seconds = ([double]$Matches.h * 3600.0) + ([double]$Matches.m * 60.0) + [double]::Parse($Matches.s, [System.Globalization.CultureInfo]::InvariantCulture)
        return [pscustomobject]@{ Seconds = $seconds; Text = (Convert-SecondsToTimestamp -Seconds $seconds); Parsed = $true }
    }

    if ($normalized -match '^(?<m>\d+)m\s*(?<s>\d{1,2}(?:\.\d+)?)s$') {
        $seconds = ([double]$Matches.m * 60.0) + [double]::Parse($Matches.s, [System.Globalization.CultureInfo]::InvariantCulture)
        return [pscustomobject]@{ Seconds = $seconds; Text = (Convert-SecondsToTimestamp -Seconds $seconds); Parsed = $true }
    }

    if ($normalized -match '^(?<a>\d+)\.(?<b>\d{1,2})\.(?<c>\d{1,2}(?:\.\d+)?)$') {
        $asMinutes = ([double]$Matches.a * 60.0) + [double]::Parse($Matches.b + '.' + $Matches.c, [System.Globalization.CultureInfo]::InvariantCulture)
        $asHours = ([double]$Matches.a * 3600.0) + ([double]$Matches.b * 60.0) + [double]::Parse($Matches.c, [System.Globalization.CultureInfo]::InvariantCulture)

        if ($null -ne $distanceKm -and $distanceKm -ge 8.0) {
            $paceHours = ($asHours / 60.0) / $distanceKm
            $paceMinutes = ($asMinutes / 60.0) / $distanceKm
            if ($paceHours -ge 2.333333 -and $paceHours -le 8.0) {
                return [pscustomobject]@{ Seconds = $asHours; Text = (Convert-SecondsToTimestamp -Seconds $asHours); Parsed = $true }
            }
            if ($paceMinutes -ge 2.333333 -and $paceMinutes -le 8.0) {
                return [pscustomobject]@{ Seconds = $asMinutes; Text = (Convert-SecondsToTimestamp -Seconds $asMinutes); Parsed = $true }
            }
        }

        return [pscustomobject]@{ Seconds = $asMinutes; Text = (Convert-SecondsToTimestamp -Seconds $asMinutes); Parsed = $true }
    }

    if ($normalized -match '^(?<m>\d{1,3})\.(?<tail>\d{3,4})$') {
        $tail = $Matches.tail
        $secondsPart = [int]$tail.Substring(0, 2)
        $hundredthsText = $tail.Substring(2)
        if ($hundredthsText.Length -eq 1) {
            $hundredthsText = $hundredthsText + '0'
        }

        if ($secondsPart -lt 60) {
            $seconds = ([double]$Matches.m * 60.0) + [double]$secondsPart + ([double]$hundredthsText / 100.0)
            return [pscustomobject]@{ Seconds = $seconds; Text = (Convert-SecondsToTimestamp -Seconds $seconds); Parsed = $true }
        }
    }

    if ($normalized -match '^(?<m>\d{1,2})[\.:](?<s>\d{1,2}(?:\.\d+)?)$') {
        $asMinutes = ([double]$Matches.m * 60.0) + [double]::Parse($Matches.s, [System.Globalization.CultureInfo]::InvariantCulture)
        if ($null -ne $distanceKm -and $distanceKm -ge 15.0) {
            $asHours = 3600.0 + $asMinutes
            return [pscustomobject]@{ Seconds = $asHours; Text = (Convert-SecondsToTimestamp -Seconds $asHours); Parsed = $true }
        }
        return [pscustomobject]@{ Seconds = $asMinutes; Text = (Convert-SecondsToTimestamp -Seconds $asMinutes); Parsed = $true }
    }

    return [pscustomobject]@{ Seconds = $null; Text = $raw; Parsed = $false }
}

function Format-ShortDuration {
    param([AllowNull()][string]$Value)

    $info = Get-RaceTimeInfo -Value $Value -Title '' -Distance '' -Category ''
    if ($null -eq $info.Seconds) {
        return ''
    }

    return $info.Text
}

function Get-Surface {
    param([AllowNull()][string]$Title)

    if ($Title -match '(?i)\bxc\b|cross country') { return 'XC' }
    if ($Title -match '(?i)\btrack\b|graded|indoor|800m|1500m|3000m|5000m') { return 'Track' }
    return 'Road'
}

function Get-Organisation {
    param(
        [AllowNull()][string]$Title,
        [AllowNull()][string]$Location
    )

    $text = (($Title, $Location) -join ' ').Trim()
    if ($text -match '(?i)international|australia|new zealand|canada|united states|usa|germany|france|spain|belgium|czech|austria|netherlands|italy|portugal|poland|sweden|norway|denmark|finland|iceland') { return 'International' }
    if ($text -match '(?i)national') { return 'National' }
    if ($text -match '(?i)leinster') { return 'Leinster' }
    if ($text -match '(?i)dublin') { return 'Dublin' }
    if ($text -match '(?i)\blvac\b') { return 'LVAC' }
    if ($text -match '(?i)club|avondale|cake race|wl') { return 'Club Races' }
    return 'Club Races'
}

function Get-Category {
    param([AllowNull()][string]$Title)

    if ($Title -match '(?i)novice') { return 'Novice' }
    if ($Title -match '(?i)inter(mediate)?') { return 'Intermediate' }
    if ($Title -match '(?i)\bsenior\b') { return 'Senior' }
    if ($Title -match '(?i)master') { return 'Master' }
    if ($Title -match '(?i)(club\s+)?championships') { return 'Club Championships' }
    return ''
}

function Resolve-OutputCategory {
    param(
        [AllowNull()][string]$TitleCategory,
        [AllowNull()][string]$ResultCategory
    )

    $resultText = Repair-Mojibake $ResultCategory
    if ($resultText -match '(?i)\bnovice\b') { return 'Novice' }
    if ($resultText -match '(?i)\binter(?:mediate)?\b') { return 'Intermediate' }
    if ($resultText -match '(?i)\bmaster\b|\b[FMwW]\d{2}\b') { return 'Master' }
    if ($resultText -match '(?i)\bsenior\b|^(MS|FS)$') { return 'Senior' }
    return $TitleCategory
}

function Get-GradeFromCategory {
    param([AllowNull()][string]$Category)

    if ([string]::IsNullOrWhiteSpace($Category)) {
        return ''
    }

    $text = $Category.Trim().ToUpperInvariant()
    if ($text -match '^(?<prefix>[MFW])(?<age>\d{2})(?:\s*\(\d+\))?$') {
        $prefix = $Matches.prefix
        if ($prefix -eq 'F') {
            $prefix = 'W'
        }
        return ($prefix + $Matches.age)
    }

    return ''
}

function Get-ResultCategoryNote {
    param([AllowNull()][string]$Category)

    if ([string]::IsNullOrWhiteSpace($Category)) {
        return ''
    }

    $text = Normalize-Note $Category
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ''
    }

    if ($text -match '(?i)^[FMW]\d{2}(?:\s*\(\d+\))?$') {
        return ''
    }
    if ($text -match '(?i)^(MS|FS|M|F|Men|Women|Inter Men|Inter Women|Senior Men|Senior Women)$') {
        return ''
    }

    if ($text -match '(?i)\b\d{3,5}m\b' -and $text -match '(?i)\b(grade\s*)?[A-Z]\b|\bH\d+\b|\bHeat\b') {
        return ('Category {0}' -f $text)
    }

    return ''
}

function Resolve-DistanceKm {
    param(
        [AllowNull()][string]$Title,
        [AllowNull()][string]$Distance,
        [AllowNull()][string]$Category,
        [AllowNull()][string]$Gender,
        [AllowNull()][string]$Note,
        [AllowNull()][string]$ResultDistance,
        [AllowNull()][double]$TimeSeconds
    )

    $distanceText = Get-DistanceKm -Title $Title -Distance $Distance -Category $Category -Gender $Gender -Note $Note -ResultDistance $ResultDistance
    $warnings = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($distanceText)) {
        $warnings.Add('Check distance')
        return [pscustomobject]@{ Distance = ''; Warnings = $warnings }
    }

    if ($null -ne $TimeSeconds) {
        $distanceKm = [double]::Parse($distanceText, [System.Globalization.CultureInfo]::InvariantCulture)
        $pace = ($TimeSeconds / 60.0) / $distanceKm
        if ($pace -lt 2.333333 -or $pace -gt 8.0) {
            $warnings.Add('Check time')
            $warnings.Add('Check distance')
        }
        if ($TimeSeconds -gt 18000) {
            $warnings.Add('Check time')
        }
    }

    return [pscustomobject]@{ Distance = $distanceText; Warnings = $warnings }
}

function Get-EventData {
    param([Parameter(Mandatory)][string]$Path)

    $content = Read-Utf8Text -Path $Path
    $lines = $content -split "`r?`n"

    $seenFrontMatterStart = $false
    $inResults = $false
    $meta = @{}
    $results = New-Object System.Collections.Generic.List[object]
    $currentResult = $null

    foreach ($line in $lines) {
        if (-not $seenFrontMatterStart) {
            if ($line.Trim() -eq '---') {
                $seenFrontMatterStart = $true
            }
            continue
        }

        if ($line.Trim() -eq '---') {
            if ($null -ne $currentResult) {
                $results.Add([pscustomobject]$currentResult)
                $currentResult = $null
            }
            break
        }

        if ($inResults) {
            if ($line -match '^\s*-\s*(?<rest>.*)$') {
                if ($null -ne $currentResult) {
                    $results.Add([pscustomobject]$currentResult)
                }
                $currentResult = @{}
                $rest = $Matches.rest.Trim()
                if ($rest) {
                    $pair = Split-KeyValue -Line $rest
                    $currentResult[$pair[0]] = $pair[1]
                }
                continue
            }

            if ($null -ne $currentResult -and $line -match '^\s+(?<key>[^:]+):(?<value>.*)$') {
                $currentResult[$Matches.key.Trim()] = Unquote-Value $Matches.value
            }
            continue
        }

        if ($line.Trim() -eq 'results:') {
            $inResults = $true
            continue
        }

        if ($line -match '^\s*(?<key>[^:]+):(?<value>.*)$') {
            $meta[$Matches.key.Trim()] = Unquote-Value $Matches.value
        }
    }

    if ($null -ne $currentResult) {
        $results.Add([pscustomobject]$currentResult)
    }

    return [pscustomobject]@{
        Meta = [pscustomobject]$meta
        Results = $results
    }
}

function Get-RowText {
    param(
        [Parameter(Mandatory)][int]$RaceId,
        [AllowNull()][string]$Date,
        [AllowNull()][string]$Location,
        [AllowNull()][string]$RaceName,
        [AllowNull()][string]$DistanceRaw,
        [AllowNull()][string]$Surface,
        [AllowNull()][string]$Organisation,
        [Parameter(Mandatory)][pscustomobject]$Result,
        [AllowNull()][string]$CategoryFromTitle,
        [Parameter(Mandatory)][hashtable]$ClubMembers
    )

    if (Test-IgnoredResult -Result $Result) {
        return $null
    }

    $place = ''
    $athleteRaw = ''
    $resultCategory = ''
    $rawNote = ''
    $estimatedRaw = ''
    $timeRaw = ''
    $finishRaw = ''
    $handicapRaw = ''
    $resultDistanceRaw = ''

    foreach ($prop in $Result.PSObject.Properties) {
        switch ($prop.Name) {
            'place' { $place = [string]$prop.Value }
            'name' { $athleteRaw = [string]$prop.Value }
            'time' { $timeRaw = [string]$prop.Value }
            'finish_time' { $finishRaw = [string]$prop.Value }
            'actual_time' { $timeRaw = [string]$prop.Value }
            'handicap' { $handicapRaw = [string]$prop.Value }
            'estimated' { $estimatedRaw = [string]$prop.Value }
            'category' { $resultCategory = [string]$prop.Value }
            'distance' { $resultDistanceRaw = [string]$prop.Value }
            'note' { $rawNote = [string]$prop.Value }
        }
    }

    $nameChanged = $false
    $athlete = Normalize-Name -Value $athleteRaw -Changed ([ref]$nameChanged)
    $memberKey = Get-NameKey $athlete
    if (-not $ClubMembers.ContainsKey($memberKey)) {
        return $null
    }
    $member = $ClubMembers[$memberKey]

    $placeNeedsCheck = $false
    $place = Normalize-Place -Value $place -NeedsCheck ([ref]$placeNeedsCheck)
    $grade = Get-GradeFromCategory $resultCategory
    $categoryOutput = Resolve-OutputCategory -TitleCategory $CategoryFromTitle -ResultCategory $resultCategory

    $timeSource = ''
    if (-not [string]::IsNullOrWhiteSpace($timeRaw)) {
        $timeSource = $timeRaw
    } else {
        $timeSource = $finishRaw
    }
    $timeInfo = Get-RaceTimeInfo -Value $timeSource -Title $RaceName -Distance $DistanceRaw -Category $resultCategory -Gender $member.Gender -Note $rawNote -ResultDistance $resultDistanceRaw
    $distanceInfo = Resolve-DistanceKm -Title $RaceName -Distance $DistanceRaw -Category $resultCategory -Gender $member.Gender -Note $rawNote -ResultDistance $resultDistanceRaw -TimeSeconds $timeInfo.Seconds

    $extras = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($estimatedRaw)) {
        $extras.Add(('Estimated {0}' -f (Format-ShortDuration $estimatedRaw)))
    }
    if (-not [string]::IsNullOrWhiteSpace($finishRaw) -and $timeRaw) {
        $extras.Add(('Finish {0}' -f (Format-ShortDuration $finishRaw)))
    }
    if (-not [string]::IsNullOrWhiteSpace($handicapRaw)) {
        $extras.Add(('Handicap {0}' -f (Format-ShortDuration $handicapRaw)))
    }

    $noteParts = New-Object System.Collections.Generic.List[string]
    $normalizedNote = Normalize-Note $rawNote
    if (-not [string]::IsNullOrWhiteSpace($normalizedNote)) {
        $noteParts.Add($normalizedNote)
    }
    $distanceAnnotation = Get-DistanceAnnotation $DistanceRaw
    if (-not [string]::IsNullOrWhiteSpace($distanceAnnotation)) {
        $noteParts.Add($distanceAnnotation)
    }
    $resultCategoryNote = Get-ResultCategoryNote $resultCategory
    if (-not [string]::IsNullOrWhiteSpace($resultCategoryNote)) {
        $noteParts.Add($resultCategoryNote)
    }
    if ($extras.Count -gt 0) {
        $noteParts.Add(($extras -join ' | '))
    }
    if ($nameChanged -or $member.Name -ne $athlete) {
        $noteParts.Add('Check name')
    }
    if ($placeNeedsCheck) {
        $noteParts.Add('Check place')
    }
    if (-not $timeInfo.Parsed -and -not [string]::IsNullOrWhiteSpace($timeSource)) {
        $noteParts.Add('Check time')
    }
    if ($timeSource -match '^\s*\d{1,3}\.\d{3,4}\s*$') {
        $noteParts.Add('Check time')
    }
    foreach ($warning in @($distanceInfo.Warnings)) {
        if (-not [string]::IsNullOrWhiteSpace($warning)) {
            $noteParts.Add($warning)
        }
    }

    $fields = @(
        $RaceId,
        $Date,
        $Location,
        $RaceName,
        $Surface,
        $Organisation,
        $place,
        $member.Name,
        $categoryOutput,
        $member.Gender,
        $grade,
        $timeInfo.Text,
        $distanceInfo.Distance,
        (($noteParts | Select-Object -Unique) -join ' | ')
    )

    return ($fields -join "`t")
}

if (-not (Test-Path -LiteralPath $ClubMembersPath)) {
    throw "Club members file not found: $ClubMembersPath"
}
$clubMembers = Load-ClubMembers -Path $ClubMembersPath

if ($Files -and $Files.Count -gt 0) {
    $inputFiles = foreach ($file in $Files) {
        if ([System.IO.Path]::IsPathRooted($file)) {
            $file
        } else {
            Join-Path $InputRoot $file
        }
    }
} else {
    $inputFiles = Get-ChildItem -LiteralPath $InputRoot -Filter '*.md' -File | Sort-Object Name | Select-Object -ExpandProperty FullName
}

if ($dateFilterActive) {
    $inputFiles = @($inputFiles | Where-Object {
            $fileName = [System.IO.Path]::GetFileName($_)
            if ($fileName -notmatch '^(?<date>\d{4}-\d{2}-\d{2})') {
                return $true
            }

            $fileDate = [datetime]::MinValue
            $validFileDate = [datetime]::TryParseExact(
                $Matches.date,
                'yyyy-MM-dd',
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::None,
                [ref]$fileDate
            )
            if (-not $validFileDate) {
                return $true
            }

            return Test-DateInRange -Date $fileDate.Date -From $dateFromValue -To $dateToValue
        })
}

if ($MaxFiles -gt 0) {
    $inputFiles = $inputFiles | Select-Object -First $MaxFiles
}

$rows = New-Object System.Collections.Generic.List[string]
$raceId = $StartId

foreach ($path in $inputFiles) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "File not found: $path"
    }

    $event = Get-EventData -Path $path
    $meta = $event.Meta
    $title = Get-OptionalProperty -Object $meta -Name 'title'
    $location = Get-OptionalProperty -Object $meta -Name 'location'
    $dateRaw = Get-OptionalProperty -Object $meta -Name 'date'
    $distanceRaw = Get-OptionalProperty -Object $meta -Name 'distance'

    $date = ''
    if ($dateRaw -match '^(?<date>\d{4}-\d{2}-\d{2})') {
        $date = $Matches.date
    }

    if ($dateFilterActive) {
        if ([string]::IsNullOrWhiteSpace($date)) {
            continue
        }

        $eventDate = [datetime]::ParseExact(
            $date,
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        if (-not (Test-DateInRange -Date $eventDate.Date -From $dateFromValue -To $dateToValue)) {
            continue
        }
    }

    $surface = Get-Surface -Title $title
    $organisation = Get-Organisation -Title $title -Location $location
    $categoryFromTitle = Get-Category -Title $title

    foreach ($result in $event.Results) {
        $rowText = Get-RowText -RaceId $raceId -Date $date -Location $location -RaceName $title -DistanceRaw $distanceRaw -Surface $surface -Organisation $organisation -Result $result -CategoryFromTitle $categoryFromTitle -ClubMembers $clubMembers
        if (-not [string]::IsNullOrWhiteSpace($rowText)) {
            $rows.Add($rowText)
        }
    }

    $raceId++
}

Write-Utf8Text -Path $OutputPath -Text (($rows -join "`r`n") + ($(if ($rows.Count -gt 0) { "`r`n" } else { '' })))

Write-Output "Loaded $($clubMembers.Count) club members"
Write-Output "Wrote $($rows.Count) rows to $OutputPath"
