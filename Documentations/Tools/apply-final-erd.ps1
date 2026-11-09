$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$path=Join-Path $root 'Chapter 3.docx'
$diagram=Join-Path $root 'Chapter 3 Diagrams'
$backup=Join-Path $root ('Review Backups/final-erd-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item -LiteralPath $path -Destination (Join-Path $backup 'Chapter 3.docx')
$work=Join-Path $backup 'Chapter 3 working.docx'
Copy-Item -LiteralPath $path -Destination $work
& (Join-Path $PSScriptRoot 'format-data-dictionary-tables.ps1') -DocumentPath $work
$z=[IO.Compression.ZipFile]::Open($work,'Update')
try{
 function ReadXml($part){$r=[IO.StreamReader]::new($z.GetEntry($part).Open());try{$x=[xml]$r.ReadToEnd();return ,$x}finally{$r.Dispose()}}
 function SaveXml($part,$x){$entry=$z.GetEntry($part);if(-not $entry){$entry=$z.CreateEntry($part)};$stream=$entry.Open();$stream.SetLength(0);$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));try{$x.Save($writer)}finally{$writer.Dispose()}}
 function Binary($part,$source){$old=$z.GetEntry($part);if($old){$old.Delete()};$entry=$z.CreateEntry($part);$s=$entry.Open();try{$bytes=[IO.File]::ReadAllBytes($source);$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
 $d=ReadXml 'word/document.xml';$rels=ReadXml 'word/_rels/document.xml.rels';$ct=ReadXml '[Content_Types].xml'
 $ns=[Xml.XmlNamespaceManager]::new($d.NameTable)
 $w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$a='http://schemas.openxmlformats.org/drawingml/2006/main';$r='http://schemas.openxmlformats.org/officeDocument/2006/relationships';$svgNs='http://schemas.microsoft.com/office/drawing/2016/SVG/main'
 $ns.AddNamespace('w',$w);$ns.AddNamespace('a',$a);$ns.AddNamespace('r',$r);$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
 function Txt($p){($p.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
 function Put($p,$text){$ts=$p.SelectNodes('.//w:t',$ns);$ts[0].InnerText=$text;foreach($t in @($ts|Select-Object -Skip 1)){$t.InnerText=''}}
 $paras=@($d.SelectNodes('//w:body/w:p',$ns));$h=@($paras|Where-Object {(Txt $_).Trim() -eq 'Entity Relationship Diagram'})[0]
 $pic=$h.NextSibling;while($pic -and -not $pic.SelectSingleNode('.//a:blip',$ns)){$pic=$pic.NextSibling};if(-not $pic){throw 'ERD picture not found'}
 $blip=$pic.SelectSingleNode('.//a:blip',$ns);$rid=$blip.GetAttribute('embed',$r)
 $rel=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $rid)[0]
 $rel.SetAttribute('Target','media/irongrind-final-erd.png')
 Binary 'word/media/irongrind-final-erd.png' (Join-Path $diagram '_Sources/05-gym-erd-word-fallback.png')
 Binary 'word/media/irongrind-final-erd.svg' (Join-Path $diagram '05-gym-erd-editable.svg')
 $svgRid='rIdIronGrindFinalSVG';$sr=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $svgRid)
 if(-not $sr){$sr=$rels.CreateElement('Relationship',$rels.DocumentElement.NamespaceURI);$sr.SetAttribute('Id',$svgRid);$sr.SetAttribute('Type',$r+'/image');$sr.SetAttribute('Target','media/irongrind-final-erd.svg');$null=$rels.DocumentElement.AppendChild($sr)}
 foreach($old in @($blip.SelectNodes('a:extLst/a:ext[@uri="{96DAC541-7B7A-43D3-8B79-37D633B846F1}"]',$ns))){$null=$old.ParentNode.RemoveChild($old)}
 $list=$blip.SelectSingleNode('a:extLst',$ns);if(-not $list){$list=$d.CreateElement('a','extLst',$a);$null=$blip.AppendChild($list)}
 $ext=$d.CreateElement('a','ext',$a);$ext.SetAttribute('uri','{96DAC541-7B7A-43D3-8B79-37D633B846F1}')
 $sb=$d.CreateElement('asvg','svgBlip',$svgNs);$null=$sb.SetAttribute('embed',$r,$svgRid);$null=$ext.AppendChild($sb);$null=$list.AppendChild($ext)
 if(-not @($ct.DocumentElement.ChildNodes|Where-Object Extension -eq 'svg')){$default=$ct.CreateElement('Default',$ct.DocumentElement.NamespaceURI);$default.SetAttribute('Extension','svg');$default.SetAttribute('ContentType','image/svg+xml');$null=$ct.DocumentElement.AppendChild($default)}
 $cx=[long](9.5*914400);$cy=[long]($cx*950/1700)
 foreach($e in $pic.SelectNodes('.//wp:extent|.//a:xfrm/a:ext',$ns)){$e.SetAttribute('cx',"$cx");$e.SetAttribute('cy',"$cy")}
 $info=$pic.SelectSingleNode('.//wp:docPr',$ns);$info.SetAttribute('name','IronGrind Public-Schema ERD');$info.SetAttribute('descr','Twelve public tables and Supabase auth.users, with nine solid public relationships and nine dashed Auth references. Selected fields show exact declared types and keys.')
 $replaced=0
 foreach($p in $paras){$t=(Txt $p).Trim()
  if($t.StartsWith('The public-schema ERD in Figure 5')){
   Put $p 'The public-schema ERD in Figure 5 presents the persistent data structure of the IronGrind Membership and Operations Management System. It contains all twelve public tables and a separate auth.users reference managed by Supabase. The public tables support account profiles, membership applications and renewals, member records, attendance, membership history, products, sales, sale items, activity logging, and mobile attendance pairing and scanning. The Auth reference is not a thirteenth public application table. All eighteen foreign keys on public tables are represented: nine solid black connections between public tables and nine pale gray dashed connections to auth.users. Selected attributes keep the one-page overview readable; the data dictionary provides all 162 public field definitions.';$replaced++
  }elseif($t.StartsWith('In Figure 5, the connecting lines')){
   Put $p 'In Figure 5, a relationship line links a referenced table to a table that stores its foreign key; it does not show the order in which screens or program operations execute. PK identifies a primary key, FK a foreign key, and UQ a unique constraint or index. A circle denotes zero, a bar denotes one, and a crow''s foot denotes many. A mandatory foreign key requires exactly one parent record, whereas a nullable foreign key allows zero or one parent. A parent may have zero or many child records unless a unique or primary-key constraint limits the referencing field to at most one. Solid and dashed connections both represent declared foreign keys: the dashed style only distinguishes Supabase identity references and does not mean that enforcement is optional. Crossings without junction symbols do not establish additional relationships. Varchar(n) gives the declared character limit; numeric(p,s) gives the total precision and decimal scale; timestamptz abbreviates timestamp with time zone. Column nullability, defaults, and referential actions are specified in the data dictionary rather than inferred from the line color.';$replaced++
  }elseif($t.StartsWith('Additional Public Relationships.')){
   Put $p 'Additional Public Relationships. Profiles.id is both a primary key and a foreign key to auth.users.id: every profile belongs to one Auth account, while an Auth account may exist without a profile. Members.auth_user_id is nullable and unique, allowing a member record without an online account and at most one linked member record per non-null Auth account. Membership_applications.auth_user_id is nullable and is not unique, allowing multiple applications to reference the same account. The nullable operator references are attendance.recorded_by, attendance.checked_out_by, sales.processed_by, membership_history.recorded_by, and mobile_attendance_pairing_policy.updated_by. Mobile_attendance_scan_sessions.created_by is required. These nine identity references are the dashed connections in the figure. Separately, membership_applications.reviewed_by optionally references profiles.id, and each mobile_attendance_scan_events row must reference one scanner session through session_id; a session may have no scan-event rows or many. The private supporting relationships are documented in the dictionary.';$replaced++
  }
 }
 if($replaced -ne 3){throw "Expected three revised explanation paragraphs, found $replaced"}
 # Introduce the existing dictionary sequence explicitly without dropping private tables.
 $intro=@($paras|Where-Object {(Txt $_).StartsWith('The data dictionary uses four columns')})[0]
 Put $intro ((Txt $intro)+' The tables are arranged from account and membership records to attendance, products and sales, membership history, audit logging, mobile scanner support, and private security and request-processing support. Each table retains the schema-qualified name and its operational purpose. Repeated header rows and consistent column widths support reading across page breaks; each field row keeps its name, declared type, constraints, and purpose together.')
 SaveXml 'word/document.xml' $d;SaveXml 'word/_rels/document.xml.rels' $rels;SaveXml '[Content_Types].xml' $ct
}finally{$z.Dispose()}
# Acquire an exclusive file handle before replacing the manuscript.
$lock=[IO.File]::Open($path,'Open','ReadWrite','None');$lock.Dispose()
Copy-Item -LiteralPath $work -Destination $path -Force
"Updated Chapter 3 with embedded SVG plus PNG compatibility preview, revised explanation, and formatted 15-table dictionary. Backup: $backup"
