$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$path=Join-Path $root 'Chapter 3.docx'
$backup=Join-Path $root ('Review Backups/sample-format-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[void][IO.Directory]::CreateDirectory($backup)
Copy-Item -LiteralPath $path -Destination (Join-Path $backup 'Chapter 3.docx')
$z=[IO.Compression.ZipFile]::Open($path,'Update')
try {
 $r=[IO.StreamReader]::new($z.GetEntry('word/document.xml').Open())
 $d=[xml]$r.ReadToEnd();$r.Dispose()
 $n=[Xml.XmlNamespaceManager]::new($d.NameTable);$n.AddNamespace('w','http://schemas.openxmlformats.org/wordprocessingml/2006/main')
 function Txt($x){return (($x.SelectNodes('.//w:t',$n)|ForEach-Object InnerText)-join '').Trim()}
 function Put($x,$s){$ts=$x.SelectNodes('.//w:t',$n);$ts[0].InnerText=$s;for($i=1;$i -lt $ts.Count;$i++){$ts[$i].InnerText=''}}
 $tables=@($d.SelectNodes('//w:body/w:tbl',$n))
 $fields=0
 foreach($table in ($tables|Select-Object -Skip 5)){
  $widths=@(1800,1300,1300,650,4310)
  $grid=$table.SelectSingleNode('w:tblGrid',$n);$grid.RemoveAll()
  foreach($width in $widths){$c=$d.CreateElement('w','gridCol',$n.LookupNamespace('w'));$c.SetAttribute('w',$n.LookupNamespace('w'),[string]$width);[void]$grid.AppendChild($c)}
  $ri=0
  foreach($row in $table.SelectNodes('w:tr',$n)){
   $cells=@($row.SelectNodes('w:tc',$n));if($cells.Count -ne 4){throw 'Expected original four-column dictionary.'}
   $lengthCell=$cells[1].CloneNode($true);[void]$row.InsertAfter($lengthCell,$cells[1])
   if($ri -eq 0){
    Put $cells[0] 'Field Name';Put $cells[1] 'Field Type';Put $lengthCell 'Length / Precision / Scale';Put $cells[2] 'Key';Put $cells[3] 'Description and Validation Details'
   }else{
    $type=Txt $cells[1];$base=$type;$length='N/A'
    if($type -match '^(varchar|character varying|numeric|decimal)\(([^)]+)\)$'){$base=$Matches[1];$length=$Matches[2]}
    elseif($type -in @('text','text[]','json','jsonb','varchar','character varying')){$length='Not declared'}
    if($base -eq 'varchar'){$base='character varying'}
    $details=Txt $cells[2];$key=[regex]::Match($details,'^((?:PK|FK|UQ)(?:, (?:PK|FK|UQ))*)\.\s').Groups[1].Value
    $validation=$details -replace '^((?:PK|FK|UQ)(?:, (?:PK|FK|UQ))*)\.\s*',''
    Put $cells[1] $base;Put $lengthCell $length;Put $cells[2] $key;Put $cells[3] ((Txt $cells[3])+' '+$validation)
    $fields++
   }
   $ci=0;foreach($cell in $row.SelectNodes('w:tc',$n)){$cell.SelectSingleNode('w:tcPr/w:tcW',$n).SetAttribute('w',$n.LookupNamespace('w'),[string]$widths[$ci]);$ci++}
   $ri++
  }
 }
 foreach($p in $d.SelectNodes('//w:body/w:p',$n)){
  $t=Txt $p
  if($t -eq 'Database Schema and Data Dictionary'){Put $p 'Entity Relationship Diagram'}
  if($t -match '^The (Length / Precision / Scale|dictionary|data dictionary)' -and $t -match 'four|Constraints|Name, Type'){
   Put $p 'The data dictionary uses five columns: Field Name, Field Type, Length / Precision / Scale, Key, and Description and Validation Details. Declared character limits and numeric precision and scale are reported separately from the base type. Not declared identifies text, array, or JSON types without a declared character maximum; N/A identifies types without a length parameter. PK, FK, and UQ identify primary, foreign, and individually unique keys. Descriptions retain nullability, referenced keys, referential actions, composite constraints, defaults, identity generation, and relevant checks. These definitions describe the documented migration model rather than a new live-database inspection.'
  }
 }
 if($fields -ne 201){throw "Unexpected field count: $fields"}
 $z.GetEntry('word/document.xml').Delete();$entry=$z.CreateEntry('word/document.xml');$w=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false));$w.Write($d.OuterXml);$w.Dispose()
 "Updated 18 dictionary tables and $fields fields. Backup: $backup"
}finally{$z.Dispose()}
