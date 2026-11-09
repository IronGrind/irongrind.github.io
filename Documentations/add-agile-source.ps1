$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$path=Join-Path $PSScriptRoot 'Chapter 3.docx'
$work=Join-Path ([IO.Path]::GetTempPath()) ('chapter3-agile-source-'+[guid]::NewGuid().ToString('N')+'.docx')
$surname='Pavlovi'+[char]0x0107
$url='https://www.linkedin.com/pulse/from-now-we-agile-enterprise-any-other-projects-misa-pavlovic-'
$title='And from now on we are Agile ... (on enterprise or any other projects for that matter)'
$note='Note. The Agile approach was informed by '+$surname+' (2018).'
$discussion=$surname+' (2018) discusses the importance of organizational support, consistent practices, and adequate skills and training when adopting Agile. This perspective informed the choice of approach for the study and supports treating iterative development as a structured process requiring planning and review. The phases shown in Figure 1 organize development tasks for IronGrind, including its membership, attendance, inventory, sales, and reporting features.'
$reference=$surname+', M. (2018, October 23). '+$title+'. LinkedIn. '+$url
Copy-Item -LiteralPath $path -Destination $work
try {
 $zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($work,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try {
  $entry=$zip.GetEntry('word/document.xml');$r=[IO.StreamReader]::new($entry.Open());$doc=[Xml.XmlDocument]::new();$doc.PreserveWhitespace=$true;$doc.LoadXml($r.ReadToEnd());$r.Dispose()
  $w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$n=[Xml.XmlNamespaceManager]::new($doc.NameTable);$n.AddNamespace('w',$w);$n.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main')
  function TextOf($p){return ($p.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join ''}
  function Attr($e,$name,$value){[void]$e.SetAttribute($name,$w,$value)}
  function Run($p,$text,$italic=$false,$bold=$false,$size='24'){
   $run=$doc.CreateElement('w','r',$w);$pr=$doc.CreateElement('w','rPr',$w);$fonts=$doc.CreateElement('w','rFonts',$w)
   foreach($name in @('ascii','hAnsi','cs','eastAsia')){Attr $fonts $name 'Times New Roman'};[void]$pr.AppendChild($fonts)
   if($bold){[void]$pr.AppendChild($doc.CreateElement('w','b',$w))};if($italic){[void]$pr.AppendChild($doc.CreateElement('w','i',$w))}
   $sz=$doc.CreateElement('w','sz',$w);Attr $sz 'val' $size;[void]$pr.AppendChild($sz);[void]$run.AppendChild($pr)
   $t=$doc.CreateElement('w','t',$w);$space=$doc.CreateAttribute('xml','space','http://www.w3.org/XML/1998/namespace');$space.Value='preserve';[void]$t.Attributes.Append($space);$t.InnerText=$text;[void]$run.AppendChild($t);[void]$p.AppendChild($run)
  }
  function Paragraph($kind,$template=$null){
   $p=$doc.CreateElement('w','p',$w);$pr=$doc.CreateElement('w','pPr',$w)
   if($template){$original=$template.SelectSingleNode('w:pPr',$n);if($original){$pr=$original.CloneNode($true)}}
   else{
    if($kind -eq 'heading'){
     $style=$doc.CreateElement('w','pStyle',$w);Attr $style 'val' 'Heading2';[void]$pr.AppendChild($style)
     [void]$pr.AppendChild($doc.CreateElement('w','keepNext',$w));[void]$pr.AppendChild($doc.CreateElement('w','pageBreakBefore',$w))
    }
    $spacing=$doc.CreateElement('w','spacing',$w);Attr $spacing 'line' $(if($kind -eq 'note'){'240'}else{'360'});Attr $spacing 'lineRule' 'auto';Attr $spacing 'after' '100';[void]$pr.AppendChild($spacing)
    if($kind -eq 'reference'){$indent=$doc.CreateElement('w','ind',$w);Attr $indent 'left' '720';Attr $indent 'hanging' '720';[void]$pr.AppendChild($indent)}
    $align=$doc.CreateElement('w','jc',$w);Attr $align 'val' $(if($kind -eq 'heading'){'center'}elseif($kind -eq 'note'){'left'}else{'both'});[void]$pr.AppendChild($align)
   }
   [void]$p.AppendChild($pr);return ,$p
  }
  $body=$doc.SelectSingleNode('//w:body',$n);$tablesBefore=@($doc.SelectNodes('//w:tbl',$n)|ForEach-Object OuterXml);$imagesBefore=@($doc.SelectNodes('//a:blip',$n)|ForEach-Object OuterXml)
  $paras=@($doc.SelectNodes('//w:body/w:p',$n));$caption=@($paras|Where-Object {(TextOf $_).Trim() -match '^Figure 1\. Agile'})
  $overview=@($paras|Where-Object {(TextOf $_).Trim().StartsWith('Agile is an iterative system-development approach')})
  if($caption.Count -ne 1 -or $overview.Count -ne 1){throw 'Expected one Agile figure caption and one methodology overview.'}
  if(-not @($paras|Where-Object {(TextOf $_).Trim() -ceq $note}).Count){
   $p=Paragraph 'note';Run $p 'Note. ' $true $false '22';Run $p ($note.Substring(6)) $false $false '22';[void]$body.InsertAfter($p,$caption[0])
  }
  $existingDiscussion=@($paras|Where-Object {(TextOf $_).Trim().StartsWith($surname+' (2018) discusses')})
  if(-not $existingDiscussion.Count){
   $p=Paragraph 'body' $overview[0];Run $p $discussion;[void]$body.InsertAfter($p,$overview[0])
  }elseif($existingDiscussion.Count -eq 1){$texts=$existingDiscussion[0].SelectNodes('.//w:t',$n);$texts[0].InnerText=$discussion;for($i=1;$i -lt $texts.Count;$i++){$texts[$i].InnerText=''}}else{throw 'Duplicate Agile source discussion.'}
  $references=@($paras|Where-Object {(TextOf $_).Trim() -ieq 'REFERENCES'})
  if($references.Count -gt 1){throw 'Multiple reference headings require review.'}
  if(-not $references.Count){
   $heading=Paragraph 'heading';Run $heading 'REFERENCES' $false $true
   $section=$body.SelectSingleNode('w:sectPr',$n);if($section){[void]$body.InsertBefore($heading,$section)}else{[void]$body.AppendChild($heading)}
  }else{$heading=$references[0]}
  if(-not @($doc.SelectNodes('//w:body/w:p',$n)|Where-Object {(TextOf $_).Contains($url)}).Count){
   $p=Paragraph 'reference';Run $p ($surname+', M. (2018, October 23). ');Run $p $title $true;Run $p ('. LinkedIn. '+$url)
   $anchor=$heading
   foreach($existing in $heading.SelectNodes('following-sibling::w:p',$n)){$text=(TextOf $existing).Trim();if($text -and [string]::Compare($text,$reference,$true) -lt 0){$anchor=$existing}else{break}}
   [void]$body.InsertAfter($p,$anchor)
  }
  if(($tablesBefore -join "`n") -cne ((@($doc.SelectNodes('//w:tbl',$n)|ForEach-Object OuterXml))-join "`n")){throw 'Unintended data-table change.'}
  if(($imagesBefore -join "`n") -cne ((@($doc.SelectNodes('//a:blip',$n)|ForEach-Object OuterXml))-join "`n")){throw 'Unintended figure-image change.'}
  $all=(@($doc.SelectNodes('//w:body/w:p',$n)|ForEach-Object {TextOf $_}))-join "`n"
  foreach($expected in @($note,$discussion,$reference)){if(([regex]::Matches($all,[regex]::Escape($expected))).Count -ne 1){throw 'Missing or duplicate Agile attribution.'}}
  $s=$entry.Open();$s.SetLength(0);$writer=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$doc.Save($writer)}finally{$writer.Dispose()}
 }finally{$zip.Dispose()}
 $check=[IO.Compression.ZipArchive]::new([IO.File]::OpenRead($work));try{$r=[IO.StreamReader]::new($check.GetEntry('word/document.xml').Open());$checkXml=[Xml.XmlDocument]::new();$checkXml.LoadXml($r.ReadToEnd());$r.Dispose()}finally{$check.Dispose()}
 Copy-Item -LiteralPath $work -Destination $path -Force
 'Added Agile source note, a cited discussion paragraph, and a formatted reference to Chapter 3; dictionary tables and figure-image links preserved.'
}finally{if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Force}}
