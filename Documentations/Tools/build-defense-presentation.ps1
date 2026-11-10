$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'Defense/Capstone Presentation.md'
$output = Join-Path $root 'Defense/Capstone Presentation.pptx'
$temporary = Join-Path $root 'Defense/Capstone Presentation.rebuilt.pptx'
$text = [IO.File]::ReadAllText($source, [Text.Encoding]::UTF8)
$matches = [regex]::Matches($text, '(?ms)^## Slide (\d+) ([^\r\n]+)\r?\n(.*?)(?=^## |\z)')
if ($matches.Count -ne 18) { throw "Expected 18 slide sections, found $($matches.Count)." }

$slides = foreach ($match in $matches) {
    $body = $match.Groups[3].Value
    $notesMatch = [regex]::Match($body, '(?s)Speaker notes:\s*(.*)$')
    $bulletsText = if ($notesMatch.Success) { $body.Substring(0, $notesMatch.Index) } else { $body }
    $bullets = @([regex]::Matches($bulletsText, '(?m)^- (.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
    $notes = if ($notesMatch.Success) { $notesMatch.Groups[1].Value.Trim() } else { '' }
    if (-not $bullets.Count -or $notes.Length -lt 40) { throw "Slide $($match.Groups[1].Value) is missing bullets or speaker notes." }
    [pscustomobject]@{ Title = $match.Groups[2].Value; Bullets = $bullets; Notes = $notes }
}

$powerPoint = $null
$presentation = $null
try {
    $powerPoint = New-Object -ComObject PowerPoint.Application
    $powerPoint.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
    $powerPoint.WindowState = 2
    $presentation = $powerPoint.Presentations.Add([Microsoft.Office.Core.MsoTriState]::msoTrue)
    $presentation.PageSetup.SlideSize = 15
    $layout = $presentation.SlideMaster.CustomLayouts.Item(2)
    for ($i = 0; $i -lt $slides.Count; $i++) {
        $slide = $presentation.Slides.AddSlide($i + 1, $layout)
        $slide.FollowMasterBackground = [Microsoft.Office.Core.MsoTriState]::msoFalse
        $slide.Background.Fill.ForeColor.RGB = 0xFFFFFF
        $slide.Shapes.Title.TextFrame.TextRange.Text = $slides[$i].Title
        $titleRange = $slide.Shapes.Title.TextFrame.TextRange
        $titleRange.Font.Name = 'Arial'
        $titleRange.Font.Size = 26
        $titleRange.Font.Bold = [Microsoft.Office.Core.MsoTriState]::msoTrue
        $titleRange.Font.Color.RGB = 0x00008B
        $bodyShape = $slide.Shapes.Placeholders(2)
        $bodyShape.TextFrame.TextRange.Text = $slides[$i].Bullets -join "`r"
        $bodyRange = $bodyShape.TextFrame.TextRange
        $bodyRange.Font.Name = 'Arial'
        $bodyRange.Font.Size = 20
        $bodyRange.Font.Color.RGB = 0x293820
        for ($paragraph = 1; $paragraph -le $bodyRange.Paragraphs().Count; $paragraph++) {
            $bodyRange.Paragraphs($paragraph).ParagraphFormat.Bullet.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
        }
        $footer = $slide.Shapes.AddTextbox(1, 45, 500, 850, 22)
        $footer.TextFrame.TextRange.Text = "IronGrind  |  Defense draft - verify deployment and screenshots  |  $($i + 1) / $($slides.Count)"
        $footer.TextFrame.TextRange.Font.Name = 'Arial'
        $footer.TextFrame.TextRange.Font.Size = 9
        $footer.TextFrame.TextRange.Font.Color.RGB = 0x718465
        $noteBody = $slide.NotesPage.Shapes.Placeholders(2)
        $noteBody.TextFrame.TextRange.Text = $slides[$i].Notes
    }
    $presentation.SaveAs($temporary, 24)
    $presentation.Close()
    $presentation = $null
    $check = $powerPoint.Presentations.Open($temporary, [Microsoft.Office.Core.MsoTriState]::msoTrue, [Microsoft.Office.Core.MsoTriState]::msoFalse, [Microsoft.Office.Core.MsoTriState]::msoFalse)
    if ($check.Slides.Count -ne $slides.Count) { throw "PowerPoint reopened $($check.Slides.Count) slides, expected $($slides.Count)." }
    $noteCount = 0
    foreach ($slide in $check.Slides) {
        $notes = $slide.NotesPage.Shapes.Placeholders(2).TextFrame.TextRange.Text
        if ($notes.Trim().Length -lt 40) { throw "Slide $($slide.SlideIndex) is missing speaker notes after reopen." }
        $noteCount++
    }
    $check.Close()
    $check = $null
    Copy-Item -LiteralPath $temporary -Destination $output -Force
    Remove-Item -LiteralPath $temporary -Force
    "PowerPoint rebuilt and reopened successfully: $($slides.Count) slides and $noteCount speaker-note sections."
} finally {
    if ($presentation) { $presentation.Close() }
    if ($powerPoint) { $powerPoint.Quit() }
}
