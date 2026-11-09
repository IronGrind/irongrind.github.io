$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out=Join-Path $PSScriptRoot 'Chapter 3 Diagrams'
$images=[Collections.Generic.List[Drawing.Image]]::new()
try {
 foreach($number in 1..4){$images.Add([Drawing.Image]::FromFile((Join-Path $out ('05-erd-'+$number+'.png'))))}
 if(@($images|Where-Object Width -NE 1800).Count){throw 'Expected the four original ERD panels at 1800 pixels wide.'}
 $topHeight=[Math]::Max($images[0].Height,$images[1].Height)
 $bottomHeight=[Math]::Max($images[2].Height,$images[3].Height)
 $combined=[Drawing.Bitmap]::new(3600,($topHeight+$bottomHeight))
 try {
  $combined.SetResolution(300,300)
  $g=[Drawing.Graphics]::FromImage($combined)
  try {
   $g.Clear([Drawing.Color]::White)
   $g.PageUnit=[Drawing.GraphicsUnit]::Pixel
   # Preserve every original pixel: no resizing, cropping, or regenerated text.
   $positions=@(@(0,0),@(1800,0),@(0,$topHeight),@(1800,$topHeight))
   for($i=0;$i -lt 4;$i++){
    $im=$images[$i];$rect=[Drawing.Rectangle]::new($positions[$i][0],$positions[$i][1],$im.Width,$im.Height)
    $g.DrawImage($im,$rect,0,0,$im.Width,$im.Height,[Drawing.GraphicsUnit]::Pixel)
   }
  }finally{$g.Dispose()}
  $file=Join-Path $out '05-erd-combined.png'
  $combined.Save($file,[Drawing.Imaging.ImageFormat]::Png)
  "Combined all four ERD panels into one $($combined.Width) x $($combined.Height) PNG: $file"
 }finally{$combined.Dispose()}
}finally{foreach($image in $images){$image.Dispose()}}
