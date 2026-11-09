$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$base=Join-Path (Split-Path $PSScriptRoot -Parent) 'Prototype Screenshots'
$model=Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $base '_Sources/prototype-layout.json')|ConvertFrom-Json
$count=0
foreach($item in $model.Figures){
 if(-not $item.Crop){continue}
 $c=$item.Crop;$image=[Drawing.Image]::FromFile($item.SourcePath)
 try{
  $part=[Drawing.Bitmap]::new([int]$c.Width,[int]$c.Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g=[Drawing.Graphics]::FromImage($part)
  try{$g.CompositingMode=[Drawing.Drawing2D.CompositingMode]::SourceCopy;$g.DrawImage($image,[Drawing.Rectangle]::new(0,0,[int]$c.Width,[int]$c.Height),[Drawing.Rectangle]::new([int]$c.X,[int]$c.Y,[int]$c.Width,[int]$c.Height),[Drawing.GraphicsUnit]::Pixel);$part.Save($item.ImagePath,[Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$part.Dispose()}
 }finally{$image.Dispose()}
 $count++
}
"Rendered $count lossless image parts; complete original captures retained."
