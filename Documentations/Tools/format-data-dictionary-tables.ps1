param([string]$DocumentPath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3.docx'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$model=Get-Content -Raw -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3 Diagrams/schema-visualizer.json')|ConvertFrom-Json
$order=@('public.profiles','public.members','public.membership_applications','public.attendance','public.products','public.sales','public.sale_items','public.membership_history','public.activity_logs','public.mobile_attendance_pairing_policy','public.mobile_attendance_scan_sessions','public.mobile_attendance_scan_events','private.attendance_scan_requests','private.admin_login_attempts','private.account_sessions')
$purposeMap=@{};$purposeTable=$null
foreach($line in Get-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3 Diagrams/data-dictionary-field-notes.md')){
 if($line -match '^## ([\w.]+)$'){$purposeTable=$Matches[1]}
 elseif($purposeTable -and $line -cmatch '^\| ([a-z_]+) \| (.+) \|$'){$purposeMap[$purposeTable+'.'+$Matches[1]]=$Matches[2].Replace('\|','|')}
}
if($purposeMap.Count -ne 174){throw 'Expected all 174 archived field descriptions.'}
$baseline=Get-Content -Raw -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) '../supabase/migrations/20261105043517_remote_schema.sql')
if($baseline -notmatch 'ALTER TABLE "public"\."activity_logs" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY'){throw 'Cannot verify activity-log identity column.'}
$work=Join-Path ([IO.Path]::GetTempPath()) ('chapter3-dictionary-'+[guid]::NewGuid().ToString('N')+'.docx')
Copy-Item -LiteralPath $DocumentPath -Destination $work
try{
 $z=[IO.Compression.ZipArchive]::new([IO.File]::Open($work,'Open','ReadWrite'),[IO.Compression.ZipArchiveMode]::Update)
 try{
  $entry=$z.GetEntry('word/document.xml');$reader=[IO.StreamReader]::new($entry.Open());$d=[Xml.XmlDocument]::new();$d.PreserveWhitespace=$true;$d.LoadXml($reader.ReadToEnd());$reader.Dispose()
  $w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$n=[Xml.XmlNamespaceManager]::new($d.NameTable);$n.AddNamespace('w',$w);$n.AddNamespace('a','http://schemas.openxmlformats.org/drawingml/2006/main')
  function Txt($node){return ($node.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join ''}
  function Attr($node,$name,$value){[void]$node.SetAttribute($name,$w,$value)}
  function Put($node,$text){$ts=$node.SelectNodes('.//w:t',$n);if(-not $ts.Count){throw 'Missing existing paragraph text.'};$ts[0].InnerText=$text;for($i=1;$i -lt $ts.Count;$i++){$ts[$i].InnerText=''}}
  function Cell($template,$text,$cellWidth,$header=$false){
   $cell=$d.CreateElement('w','tc',$w);$old=$template.SelectSingleNode('w:tcPr',$n);$pr=if($old){$old.CloneNode($true)}else{$d.CreateElement('w','tcPr',$w)}
   $size=$pr.SelectSingleNode('w:tcW',$n);if(-not $size){$size=$d.CreateElement('w','tcW',$w);[void]$pr.PrependChild($size)};Attr $size 'w' "$cellWidth";Attr $size 'type' 'dxa';[void]$cell.AppendChild($pr)
   $p=$d.CreateElement('w','p',$w);$pp=$d.CreateElement('w','pPr',$w);$spacing=$d.CreateElement('w','spacing',$w);Attr $spacing 'before' '0';Attr $spacing 'after' '0';Attr $spacing 'line' '240';Attr $spacing 'lineRule' 'auto';[void]$pp.AppendChild($spacing)
   $indent=$d.CreateElement('w','ind',$w);Attr $indent 'left' '0';Attr $indent 'right' '0';Attr $indent 'firstLine' '0';[void]$pp.AppendChild($indent)
   $align=$d.CreateElement('w','jc',$w);Attr $align 'val' 'left';[void]$pp.AppendChild($align);[void]$p.AppendChild($pp)
   $run=$d.CreateElement('w','r',$w);$rp=$d.CreateElement('w','rPr',$w);$fonts=$d.CreateElement('w','rFonts',$w);foreach($name in @('ascii','hAnsi','cs','eastAsia')){Attr $fonts $name 'Times New Roman'};[void]$rp.AppendChild($fonts)
   $bold=$d.CreateElement('w','b',$w);Attr $bold 'val' $(if($header){'1'}else{'0'});[void]$rp.AppendChild($bold);$fontSize=$d.CreateElement('w','sz',$w);Attr $fontSize 'val' '24';[void]$rp.AppendChild($fontSize);[void]$run.AppendChild($rp)
   $t=$d.CreateElement('w','t',$w);$t.InnerText=$text;[void]$run.AppendChild($t);[void]$p.AppendChild($run);[void]$cell.AppendChild($p);return ,$cell
  }
  $tables=@($d.SelectNodes('//w:body/w:tbl',$n));if($tables.Count -ne 20){throw 'Expected five requirements and fifteen dictionary tables.'}
  $requirements=(@($tables|Select-Object -First 5|ForEach-Object OuterXml))-join "`n";$images=(@($d.SelectNodes('//a:blip',$n)|ForEach-Object OuterXml))-join "`n"
  $section=$d.SelectSingleNode('//w:body/w:sectPr',$n);$page=$section.SelectSingleNode('w:pgSz',$n);$margins=$section.SelectSingleNode('w:pgMar',$n)
  $totalWidth=[int]$page.GetAttribute('w',$w)-[int]$margins.GetAttribute('left',$w)-[int]$margins.GetAttribute('right',$w)
  $widths=@([int]($totalWidth*0.25),[int]($totalWidth*0.16),[int]($totalWidth*0.34),0);$widths[3]=$totalWidth-$widths[0]-$widths[1]-$widths[2]
  $notes=[Collections.Generic.List[string]]::new();$notes.Add('# Data dictionary field-purpose notes');$notes.Add('');$notes.Add('Field descriptions retained from the detailed Chapter 3 dictionary before conversion to the Name / Type / Constraints table format. The Word document contains the current technical constraints; these notes retain field purposes for reference.')
  $fieldCount=0;$fkCount=0;$uqCount=0;$archived=$false
  for($ti=0;$ti -lt $order.Count;$ti++){
   $table=$tables[$ti+5];$name=$order[$ti];$schemaTable=$model.Tables|Where-Object Name -EQ $name;$rows=@($table.SelectNodes('w:tr',$n));if($rows.Count-1 -ne $schemaTable.Columns.Count){throw "Field count mismatch: $name"}
   $originalCells=@($rows[0].SelectNodes('w:tc',$n));$oldCount=$originalCells.Count;if($oldCount -notin @(3,4,5)){throw 'Unexpected dictionary layout.'}
   $notes.Add('');$notes.Add('## '+$name);$notes.Add('');$notes.Add('| Field | Purpose |');$notes.Add('|---|---|')
   for($ri=0;$ri -lt $rows.Count;$ri++){
    $row=$rows[$ri];$cells=@($row.SelectNodes('w:tc',$n));if($cells.Count -ne $oldCount){throw 'Inconsistent number of dictionary cells.'}
    if($ri -eq 0){$texts=@('Name','Type','Constraints','Description')}
    else{
     $field=(Txt $cells[0]).Trim();$column=@($schemaTable.Columns|Where-Object Name -EQ $field);if($column.Count -ne 1){throw "Unknown dictionary field: $name.$field"};$column=$column[0]
     $keys=@(@('PK','FK','UQ')|Where-Object {$_ -in $column.Keys});$prefix=if($keys.Count){($keys-join ', ')+'. '}else{''}
     if($oldCount -eq 5){
      $oldDetails=Txt $cells[4];$split=[regex]::Split($oldDetails,'\s+Constraints:\s*',2);if($split.Count -ne 2){throw "Missing verified constraints for $name.$field"};$details=$split[1]
      $notes.Add('| '+$field+' | '+($split[0].Replace('|','\|'))+' |');$archived=$true
     }else{$details=(Txt $cells[2]) -replace '^(?:PK|FK|UQ)(?:, (?:PK|FK|UQ))*\.\s*',''}
     $details=$details -replace '^Identity \(GENERATED ALWAYS\)\.\s*',''
     if($name -eq 'public.activity_logs' -and $field -eq 'id'){$details='Identity (GENERATED ALWAYS). '+$details}
     $required=if($column.Required){'NOT NULL.'}else{'Nullable at column level.'};if(-not $details.Contains($required)){throw "Nullability mismatch: $name.$field"}
     $fks=@($model.Relations|Where-Object {$_.Child -eq $name -and $_.Field -eq $field});foreach($fk in $fks){if(-not $details.Contains('References '+$fk.Parent+'('+$fk.ParentField+'); ON DELETE '+$fk.Delete+'; ON UPDATE NO ACTION.')){throw "Reference mismatch: $name.$field"};$fkCount++}
     if('UQ' -in $keys){if($details -notmatch '(?i)must be unique'){throw 'Missing uniqueness requirement.'};$uqCount++}
     $purpose=if($oldCount -eq 4){(Txt $cells[3]).Trim()}else{$purposeMap[$name+'.'+$field]}
     if(-not $purpose){throw "Missing field description: $name.$field"}
     $texts=@($field,$column.Type,($prefix+$details),$purpose);$fieldCount++
    }
    $sourceIndices=if($oldCount -eq 5){@(0,1,4,4)}elseif($oldCount -eq 4){@(0,1,2,3)}else{@(0,1,2,2)};$newCells=@(for($i=0;$i -lt 4;$i++){Cell $cells[$sourceIndices[$i]] $texts[$i] $widths[$i] ($ri -eq 0)})
    foreach($oldCell in $cells){[void]$row.RemoveChild($oldCell)};foreach($newCell in $newCells){[void]$row.AppendChild($newCell)}
    $trPr=$row.SelectSingleNode('w:trPr',$n);if(-not $trPr){$trPr=$d.CreateElement('w','trPr',$w);[void]$row.PrependChild($trPr)}
    if(-not $trPr.SelectSingleNode('w:cantSplit',$n)){[void]$trPr.AppendChild($d.CreateElement('w','cantSplit',$w))}
    if($ri -eq 0 -and -not $trPr.SelectSingleNode('w:tblHeader',$n)){[void]$trPr.AppendChild($d.CreateElement('w','tblHeader',$w))}
   }
   $grid=$table.SelectSingleNode('w:tblGrid',$n);if(-not $grid){throw 'Table grid missing.'};$grid.RemoveAll();foreach($width in $widths){$col=$d.CreateElement('w','gridCol',$w);Attr $col 'w' "$width";[void]$grid.AppendChild($col)}
   $pr=$table.SelectSingleNode('w:tblPr',$n);$tw=$pr.SelectSingleNode('w:tblW',$n);if(-not $tw){$tw=$d.CreateElement('w','tblW',$w);[void]$pr.PrependChild($tw)};Attr $tw 'w' "$totalWidth";Attr $tw 'type' 'dxa'
   $layout=$pr.SelectSingleNode('w:tblLayout',$n);if(-not $layout){$layout=$d.CreateElement('w','tblLayout',$w);[void]$pr.AppendChild($layout)};Attr $layout 'type' 'fixed'
  }
  if($fieldCount -ne 174 -or $fkCount -ne 21 -or $uqCount -ne 5){throw 'Incomplete data dictionary conversion.'}
  $intro=$null
  foreach($p in $d.SelectNodes('//w:body/w:p',$n)){
   $text=(Txt $p).Trim()
   if($text.StartsWith('The Length / Precision / Scale column reports') -or $text.StartsWith('The data dictionary uses three columns') -or $text.StartsWith('The data dictionary uses four columns')){
    Put $p 'The data dictionary uses four columns: Name, Type, Constraints, and Description. Name identifies the actual database column. Type includes declared character limits and numeric precision/scale, such as varchar(150) and numeric(12,2); text[] denotes an array of text values, and timestamptz denotes timestamp with time zone. Constraints identifies primary keys (PK), foreign keys (FK), unique constraints or indexes (UQ), required or nullable state, referenced schema/table/column, update/deletion actions, composite-key membership, identity generation, and relevant CHECK rules. Nullable at column level remains subject to any conditional check stated in the row. Text and JSON types have no declared character maximum unless a separate check imposes one. Description explains the operational purpose of each field. Table-purpose paragraphs and the ERD discussion explain the wider system context.';$intro=$p
   }
   elseif($text.StartsWith('Figure 5 covers all twelve public')){Put $p 'Figure 5 covers all twelve public tables and their eighteen foreign-key relationships, with auth.users included only as a referenced identity table. All fifteen application tables and twenty-one foreign keys remain documented in the dictionary. Its Name, Type, Constraints, and Description columns record field purposes, actual field names and declared types, primary/foreign/unique key roles, composite-key membership, referenced columns, nullability, deletion/update actions, and relevant checks. For example, attendance.member_id uses ON DELETE CASCADE while membership_history.member_id uses ON DELETE RESTRICT. The retained receipt_number column is an internal transaction reference; it does not establish customer receipt issuance. A relationship line does not grant permission to view or modify records, because role checks, policies, and authorized functions control access.'}
  }
  if(-not $intro){throw 'Cannot locate the dictionary introduction.'}
  $legacy='Legacy identifier fields. Members sign in using their email address. New member records do not receive a username; members sign in using email. Current member registration uses email and does not collect a username. The nullable username columns in members and membership_applications remain for compatibility. The profiles.username field supports assigned staff and administrator identifiers. Their presence in the schema does not mean that member registration collects a username.'
  $existing=@($d.SelectNodes('//w:body/w:p',$n)|Where-Object {(Txt $_).Trim().StartsWith('Legacy identifier fields.')})
  if($existing.Count){Put $existing[0] $legacy}else{$p=$d.CreateElement('w','p',$w);$pp=$intro.SelectSingleNode('w:pPr',$n);if($pp){[void]$p.AppendChild($pp.CloneNode($true))};$run=$d.CreateElement('w','r',$w);$rp=$d.CreateElement('w','rPr',$w);$fonts=$d.CreateElement('w','rFonts',$w);foreach($name in @('ascii','hAnsi','cs','eastAsia')){Attr $fonts $name 'Times New Roman'};[void]$rp.AppendChild($fonts);$sz=$d.CreateElement('w','sz',$w);Attr $sz 'val' '24';[void]$rp.AppendChild($sz);[void]$run.AppendChild($rp);$t=$d.CreateElement('w','t',$w);$t.InnerText=$legacy;[void]$run.AppendChild($t);[void]$p.AppendChild($run);[void]$intro.ParentNode.InsertAfter($p,$intro)}
  if($requirements -cne ((@($d.SelectNodes('//w:body/w:tbl',$n)|Select-Object -First 5|ForEach-Object OuterXml))-join "`n")){throw 'Requirements tables changed unexpectedly.'}
  if($images -cne ((@($d.SelectNodes('//a:blip',$n)|ForEach-Object OuterXml))-join "`n")){throw 'Figure links changed unexpectedly.'}
  $stream=$entry.Open();$stream.SetLength(0);$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));try{$d.Save($writer)}finally{$writer.Dispose()}
 }finally{$z.Dispose()}
 $check=[IO.Compression.ZipArchive]::new([IO.File]::OpenRead($work));try{$r=[IO.StreamReader]::new($check.GetEntry('word/document.xml').Open());$xml=[Xml.XmlDocument]::new();$xml.LoadXml($r.ReadToEnd());$r.Dispose()}finally{$check.Dispose()}
 $archive=Join-Path (Split-Path $PSScriptRoot -Parent) 'Chapter 3 Diagrams/data-dictionary-field-notes.md';if($archived -and -not (Test-Path -LiteralPath $archive)){[IO.File]::WriteAllLines($archive,$notes,[Text.UTF8Encoding]::new($false))}
 Copy-Item -LiteralPath $work -Destination $DocumentPath -Force
 'Formatted all 15 dictionary tables as Name / Type / Constraints / Description; all 174 descriptions, declared types, keys and verified constraints are present.'
}finally{if(Test-Path -LiteralPath $work){Remove-Item -LiteralPath $work -Force}}
