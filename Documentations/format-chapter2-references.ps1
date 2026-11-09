$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$path=Join-Path $PSScriptRoot 'Chapter 2.docx'
$work=Join-Path ([IO.Path]::GetTempPath()) ('chapter2-references-'+[guid]::NewGuid().ToString('N')+'.docx')
Copy-Item -LiteralPath $path -Destination $work
try {
 $zip=[IO.Compression.ZipArchive]::new([IO.File]::Open($work,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try {
  $entry=$zip.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open())
  $doc=[Xml.XmlDocument]::new();$doc.PreserveWhitespace=$true;$doc.LoadXml($reader.ReadToEnd());$reader.Dispose()
  $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$ns.AddNamespace('w',$w)
  function TextOf($p){return ($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
  function Attribute($node,$name,$value){[void]$node.SetAttribute($name,$w,$value)}
  function Properties($p){$pr=$p.SelectSingleNode('w:pPr',$ns);if(-not $pr){$pr=$doc.CreateElement('w','pPr',$w);[void]$p.PrependChild($pr)};return ,$pr}
  function FontProperties($italic=$false,$bold=$false){
   $pr=$doc.CreateElement('w','rPr',$w);$font=$doc.CreateElement('w','rFonts',$w);foreach($name in @('ascii','hAnsi','cs','eastAsia')){Attribute $font $name 'Times New Roman'};[void]$pr.AppendChild($font)
   if($bold){[void]$pr.AppendChild($doc.CreateElement('w','b',$w))}
   if($italic){[void]$pr.AppendChild($doc.CreateElement('w','i',$w))}
   $size=$doc.CreateElement('w','sz',$w);Attribute $size 'val' '24';[void]$pr.AppendChild($size)
   return ,$pr
  }
  function Run($p,$text,$italic=$false,$bold=$false){
   if(-not $text.Length){return};$r=$doc.CreateElement('w','r',$w);[void]$r.AppendChild((FontProperties $italic $bold));$t=$doc.CreateElement('w','t',$w)
   $space=$doc.CreateAttribute('xml','space','http://www.w3.org/XML/1998/namespace');$space.Value='preserve';[void]$t.Attributes.Append($space)
   $t.InnerText=$text;[void]$r.AppendChild($t);[void]$p.AppendChild($r)
  }
  $paragraphs=@($doc.SelectNodes('//w:body/w:p',$ns));$heading=$null;$entries=[Collections.Generic.List[object]]::new();$body=[Collections.Generic.List[object]]::new()
  foreach($p in $paragraphs){$text=(TextOf $p).Trim();if($text -ieq 'References'){$heading=$p;continue};if(-not $heading){$body.Add($p)}elseif($text){$entries.Add([pscustomobject]@{Paragraph=$p;Text=$text;Italic=''})}}
  if(-not $heading -or $entries.Count -ne 14){throw 'Expected one reference heading followed by 14 reference entries.'}
  $supabaseTitles=@{'Production checklist'='a';'Row level security'='b';'Supabase platform'='c';'User sessions'='d'}
  $labelMap=@{}
  foreach($entry in $entries){
   if($entry.Text -match '^Supabase\. \(n\.d\.-([a-d])\)\. (.+?)\. Retrieved'){
    $old=$Matches[1];$title=$Matches[2];if(-not $supabaseTitles.ContainsKey($title)){throw "Unexpected Supabase title: $title"}
    $new=$supabaseTitles[$title];$labelMap[$old]=$new;$entry.Text=$entry.Text.Replace('(n.d.-'+$old+')','(n.d.-'+$new+')');$entry.Italic=$title
   }
   elseif($entry.Text.StartsWith('Al-Kofahi,')){$entry.Italic='International Journal of Business Information Systems, 48'}
   elseif($entry.Text.StartsWith('Babili,')){$entry.Italic='An integrated smart management system for fitness centers'}
   elseif($entry.Text.StartsWith('Bulaclac,')){$entry.Italic='Interdisciplinary Journal of Information, Knowledge, and Management, 20'}
   elseif($entry.Text.StartsWith('Gymdesk.')){$entry.Italic='How a BJJ black belt built Gymdesk from nights and weekends to a multi-million dollar SaaS company'}
   elseif($entry.Text.StartsWith('GymMaster.') -or $entry.Text.StartsWith('GYMMANAGER.')){$entry.Italic='Gym management software'}
   elseif($entry.Text.StartsWith('International Organization for Standardization.')){$entry.Italic='Information technology - Automatic identification and data capture techniques - QR code bar code symbology specification'}
   elseif($entry.Text.StartsWith('National Privacy Commission.')){$entry.Italic='The NPC celebrates 10 years of protecting data privacy of every Filipino'}
   elseif($entry.Text.StartsWith('Villanueva,')){$entry.Italic='South Florida Journal of Development, 6'}
   elseif(-not $entry.Text.StartsWith('Republic Act No. 10173,')){throw "Unrecognized reference: $($entry.Text)"}
  }
  if($labelMap.Count -ne 4){throw 'Expected all four Supabase source labels.'}
  $citationCount=0
  foreach($p in $body){
   $text=TextOf $p;$matches=[regex]::Matches($text,'Supabase(?:,\s*|\s*\()n\.d\.-(?<label>[a-d])')
   foreach($match in $matches){
    $label=$match.Groups['label'];$position=$label.Index;$offset=0;$replaced=$false
    foreach($t in $p.SelectNodes('.//w:t',$ns)){
     if($position -lt $offset+$t.InnerText.Length){$local=$position-$offset;$value=$t.InnerText;$t.InnerText=$value.Substring(0,$local)+$labelMap[$label.Value]+$value.Substring($local+1);$replaced=$true;break}
     $offset+=$t.InnerText.Length
    }
    if(-not $replaced){throw 'Unable to update Supabase citation without changing its formatting.'};$citationCount++
   }
  }
  if($citationCount -ne 4){throw "Expected four Supabase in-text citations, found $citationCount"}
  # Set the visible heading and paragraph alignment; retain the document's heading style.
  foreach($node in @($heading.ChildNodes|Where-Object LocalName -NE 'pPr')){[void]$heading.RemoveChild($node)}
  Run $heading 'REFERENCES' $false $true
  $pr=Properties $heading;$jc=$pr.SelectSingleNode('w:jc',$ns);if(-not $jc){$jc=$doc.CreateElement('w','jc',$w);$runProps=$pr.SelectSingleNode('w:rPr',$ns);if($runProps){[void]$pr.InsertBefore($jc,$runProps)}else{[void]$pr.AppendChild($jc)}};Attribute $jc 'val' 'center'
  $sorted=@($entries|Sort-Object @{Expression={$_.Text.ToLowerInvariant()}})
  $anchor=$heading;$italicCount=0
  foreach($entry in $sorted){
   $p=$entry.Paragraph
   foreach($node in @($p.ChildNodes|Where-Object LocalName -NE 'pPr')){[void]$p.RemoveChild($node)}
   if($entry.Italic){
    $index=$entry.Text.IndexOf($entry.Italic,[StringComparison]::Ordinal)
    if($index -lt 0){throw "Italic title not found: $($entry.Italic)"}
    Run $p $entry.Text.Substring(0,$index)
    Run $p $entry.Italic $true
    Run $p $entry.Text.Substring($index+$entry.Italic.Length)
    $italicCount++
   }else{Run $p $entry.Text}
   [void]$anchor.ParentNode.InsertAfter($p,$anchor);$anchor=$p
   if((TextOf $p) -cne $entry.Text){throw 'Reference text changed unexpectedly.'}
   $ind=$p.SelectSingleNode('w:pPr/w:ind',$ns)
   if(-not $ind -or $ind.GetAttribute('hanging',$w) -ne '720' -or $ind.GetAttribute('left',$w) -ne '720'){throw 'Reference hanging indent is not 0.5 inch.'}
  }
  if($italicCount -ne 13){throw "Expected 13 references with italic titles or journal/volume names, found $italicCount"}
  $checks=@(
   @('Supabase, n.d.-c','Supabase. (n.d.-c). Supabase platform.'),
   @('Supabase (n.d.-a)','Supabase. (n.d.-a). Production checklist.'),
   @('Supabase (n.d.-b)','Supabase. (n.d.-b). Row level security.'),
   @('Supabase (n.d.-d)','Supabase. (n.d.-d). User sessions.')
  )
  $bodyText=($body|ForEach-Object {TextOf $_})-join "`n";$refText=($sorted.Text)-join "`n"
  foreach($check in $checks){if(-not $bodyText.Contains($check[0]) -or -not $refText.Contains($check[1])){throw 'Supabase citation-to-reference mapping failed.'}}
  $s=$entry=$null;$entry=$zip.GetEntry('word/document.xml');$s=$entry.Open();$s.SetLength(0);$writer=[IO.StreamWriter]::new($s,[Text.UTF8Encoding]::new($false));try{$doc.Save($writer)}finally{$writer.Dispose()}
 }finally{$zip.Dispose()}
 # Reopen the completed package before replacing the working document.
 $checkZip=[IO.Compression.ZipArchive]::new([IO.File]::OpenRead($work));try{$reader=[IO.StreamReader]::new($checkZip.GetEntry('word/document.xml').Open());[xml]$checkXml=$reader.ReadToEnd();$reader.Dispose()}finally{$checkZip.Dispose()}
 Copy-Item -LiteralPath $work -Destination $path -Force
 'Chapter 2 references formatted: centered bold REFERENCES heading; 14 alphabetized entries; 13 appropriate italic spans; 0.5-inch hanging indents; four matched Supabase citations.'
}finally{if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Force}}
