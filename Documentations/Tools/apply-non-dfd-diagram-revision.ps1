$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$source=Join-Path $root 'Chapter 3.docx'
$backup=Join-Path $root 'Review Backups/non-dfd-diagrams-20261111/Chapter 3.docx'
$work=Join-Path $root 'Review Backups/non-dfd-diagrams-20261111/Chapter 3 revised.docx'
if((Get-FileHash $source).Hash -ne (Get-FileHash $backup).Hash -and (-not (Test-Path $work) -or (Get-FileHash $source).Hash -ne (Get-FileHash $work).Hash)){throw 'Manuscript changed outside this revision; inspect before proceeding.'}
Copy-Item -LiteralPath $backup -Destination $work -Force
$zip=[IO.Compression.ZipFile]::Open($work,'Update')
try {
 function ReadXml($part){$reader=[IO.StreamReader]::new($zip.GetEntry($part).Open());try{$xml=[Xml.XmlDocument]::new();$xml.PreserveWhitespace=$true;$xml.LoadXml($reader.ReadToEnd());return ,$xml}finally{$reader.Dispose()}}
 $doc=ReadXml 'word/document.xml';$rels=ReadXml 'word/_rels/document.xml.rels'
 $w='http://schemas.openxmlformats.org/wordprocessingml/2006/main';$a='http://schemas.openxmlformats.org/drawingml/2006/main';$r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'
 $ns=[Xml.XmlNamespaceManager]::new($doc.NameTable);$ns.AddNamespace('w',$w);$ns.AddNamespace('a',$a);$ns.AddNamespace('r',$r);$ns.AddNamespace('wp','http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
 function Txt($node){($node.SelectNodes('.//w:t',$ns)|ForEach-Object InnerText)-join ''}
 function One($text){$found=@($doc.SelectNodes('//w:body/w:p',$ns)|Where-Object {(Txt $_).Trim() -eq $text});if($found.Count -ne 1){throw "Expected one paragraph: $text"};return $found[0]}
 function Prefix($text){$found=@($doc.SelectNodes('//w:body/w:p',$ns)|Where-Object {(Txt $_).Trim().StartsWith($text)});if($found.Count -ne 1){throw "Expected one paragraph prefix: $text"};return $found[0]}
 function Put($node,$value){$texts=$node.SelectNodes('.//w:t',$ns);if(-not $texts.Count){throw 'No text run'};$texts[0].InnerText=$value;foreach($t in @($texts|Select-Object -Skip 1)){$t.InnerText=''}}
 function Attr($node,$name,$value){[void]$node.SetAttribute($name,$w,[string]$value)}
 function NewPara($value,$caption=$false){
  $p=$doc.CreateElement('w','p',$w);$pr=$doc.CreateElement('w','pPr',$w);$spacing=$doc.CreateElement('w','spacing',$w);Attr $spacing 'after' 160;Attr $spacing 'line' $(if($caption){240}else{360});Attr $spacing 'lineRule' 'auto';[void]$pr.AppendChild($spacing)
  $jc=$doc.CreateElement('w','jc',$w);Attr $jc 'val' $(if($caption){'center'}else{'both'});[void]$pr.AppendChild($jc)
  if(-not $caption){$ind=$doc.CreateElement('w','ind',$w);Attr $ind 'firstLine' 720;[void]$pr.AppendChild($ind)}
  [void]$p.AppendChild($pr);$run=$doc.CreateElement('w','r',$w);$rp=$doc.CreateElement('w','rPr',$w);$font=$doc.CreateElement('w','rFonts',$w);Attr $font 'ascii' 'Times New Roman';Attr $font 'hAnsi' 'Times New Roman';[void]$rp.AppendChild($font);$size=$doc.CreateElement('w','sz',$w);Attr $size 'val' 24;[void]$rp.AppendChild($size);[void]$run.AppendChild($rp);$t=$doc.CreateElement('w','t',$w);$t.InnerText=$value;[void]$run.AppendChild($t);[void]$p.AppendChild($run);return $p
 }
 function ImageAfter($heading){$p=$heading.NextSibling;while($p -and -not $p.SelectSingleNode('.//a:blip',$ns)){if((Txt $p).Trim()){throw 'Unexpected content before figure'};$p=$p.NextSibling};if(-not $p){throw 'Missing image'};return $p}
 $tablesBefore=(@($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml))-join ''
 $allBefore=@($doc.SelectNodes('//w:body/w:p',$ns));$agileBefore=($allBefore[0..24]|ForEach-Object OuterXml)-join ''
 $dfdStart=One 'Data Flow Diagram';$dfdEnd=One 'Use Case Diagram'
 function Between($start,$end){$s='';$p=$start;while($p -and -not [object]::ReferenceEquals($p,$end)){$s+=$p.OuterXml;$p=$p.NextSibling};if(-not $p){throw 'Invalid range'};return $s}
 $dfdBefore=Between $dfdStart $dfdEnd
 $changedParts=[Collections.Generic.List[string]]::new()
 function ReplaceImage($p,$name,$width){
  $blip=$p.SelectSingleNode('.//a:blip',$ns);$rid=$blip.GetAttribute('embed',$r);$rel=@($rels.DocumentElement.ChildNodes|Where-Object Id -eq $rid);if($rel.Count -ne 1){throw 'Ambiguous image relationship'};$part='word/'+$rel[0].GetAttribute('Target');$file=Join-Path $root ('Chapter 3 Diagrams/'+$name+'.png');$bytes=[IO.File]::ReadAllBytes($file)
  $entry=$zip.GetEntry($part);$entry.Delete();$s=$zip.CreateEntry($part).Open();$s.Write($bytes,0,$bytes.Length);$s.Dispose();$changedParts.Add($part)
  # Remove stale vector alternatives and crop settings so Word displays the verified PNG.
  foreach($node in @($blip.SelectNodes('a:extLst',$ns))){[void]$node.ParentNode.RemoveChild($node)}
  foreach($crop in @($p.SelectNodes('.//a:srcRect',$ns))){[void]$crop.ParentNode.RemoveChild($crop)}
  $image=[Drawing.Image]::FromFile($file);$cx=[long]($width*914400);$cy=[long]($cx*$image.Height/$image.Width);$image.Dispose()
  foreach($e in $p.SelectNodes('.//wp:extent|.//a:xfrm/a:ext',$ns)){$e.SetAttribute('cx',"$cx");$e.SetAttribute('cy',"$cy")}
  $pr=$p.SelectSingleNode('w:pPr',$ns);if(-not $pr){$pr=$doc.CreateElement('w','pPr',$w);[void]$p.PrependChild($pr)}
  foreach($node in @($pr.SelectNodes('w:spacing|w:ind|w:jc|w:keepNext',$ns))){[void]$pr.RemoveChild($node)}
  $jc=$doc.CreateElement('w','jc',$w);Attr $jc 'val' 'center';[void]$pr.AppendChild($jc);$keep=$doc.CreateElement('w','keepNext',$w);[void]$pr.PrependChild($keep);$sp=$doc.CreateElement('w','spacing',$w);Attr $sp 'line' 240;Attr $sp 'lineRule' 'auto';[void]$pr.AppendChild($sp)
 }
 function Landscape($heading,$caption){
  $body=$heading.ParentNode
  # A section's properties describe the content preceding its section break.
  foreach($pair in @(@($heading,$false,'before'),@($caption,$true,'after'))){
   $p=$doc.CreateElement('w','p',$w);$pr=$doc.CreateElement('w','pPr',$w);$sec=$doc.CreateElement('w','sectPr',$w);$type=$doc.CreateElement('w','type',$w);Attr $type 'val' 'nextPage';[void]$sec.AppendChild($type);$sz=$doc.CreateElement('w','pgSz',$w);Attr $sz 'w' $(if($pair[1]){15840}else{12240});Attr $sz 'h' $(if($pair[1]){12240}else{15840});if($pair[1]){Attr $sz 'orient' 'landscape'};[void]$sec.AppendChild($sz);$mar=$doc.CreateElement('w','pgMar',$w);foreach($key in @('top','bottom','left','right')){Attr $mar $key 1440};Attr $mar 'header' 708;Attr $mar 'footer' 708;Attr $mar 'gutter' 0;[void]$sec.AppendChild($mar);[void]$pr.AppendChild($sec);[void]$p.AppendChild($pr)
   if($pair[2] -eq 'before'){[void]$body.InsertBefore($p,$pair[0])}else{[void]$body.InsertAfter($p,$pair[0])}
  }
  # Give the wide figures 7.5 inches vertically while retaining one-inch side margins.
  $landscapeSec=$caption.NextSibling.SelectSingleNode('w:pPr/w:sectPr',$ns);$margins=$landscapeSec.SelectSingleNode('w:pgMar',$ns);Attr $margins 'top' 720;Attr $margins 'bottom' 720
  foreach($p in @($heading,$caption)){
   $pr=$p.SelectSingleNode('w:pPr',$ns)
   foreach($node in @($pr.SelectNodes('w:pageBreakBefore|w:spacing|w:keepNext',$ns))){[void]$pr.RemoveChild($node)}
   $spacing=$doc.CreateElement('w','spacing',$w);Attr $spacing 'before' 0;Attr $spacing 'after' 80;Attr $spacing 'line' 240;Attr $spacing 'lineRule' 'auto';[void]$pr.AppendChild($spacing)
   if([object]::ReferenceEquals($p,$heading)){$keep=$doc.CreateElement('w','keepNext',$w);[void]$pr.PrependChild($keep)}
  }
 }
 $contextHeading=One 'Context Diagram';$contextPic=ImageAfter $contextHeading;$contextCaption=One 'Figure 2. Context - Gane-Sarson'
 ReplaceImage $contextPic '02-context' 9
 Put (Prefix 'The Administrator entity exchanges') 'The Administrator entity submits credentials, application and renewal review decisions, membership operations, product and stock updates, product-sale entries, staff and device instructions, and report or activity-log queries. These inputs represent separate authorized requests rather than one combined transaction. Membership operations include supported counter registration, renewal, and plan changes. Staff controls concern staff accounts, while device controls concern the supported scanner and trusted-browser arrangements. Queries retrieve information; they do not themselves change the underlying business records.'
 Put (Prefix "The Administrator's outgoing flow") 'The system returns administrator access results, operation confirmations, member and staff information, device states, reports, and recorded activity. The return flow lets the administrator confirm a submitted operation or inspect information within the permitted scope. Viewing an existing member personal profile remains read-only. Membership approval, renewal, and plan changes are operational responsibilities and do not authorize editing that member personal profile.'
 Landscape $contextHeading $contextCaption
 $useHeading=One 'Use Case Diagram';$usePic=ImageAfter $useHeading
 if(@($doc.SelectNodes('//w:body/w:p',$ns)|Where-Object {(Txt $_).Trim() -eq 'Figure 4. Use Case Diagram'}).Count){throw 'Caption already exists'}
 $useCaption=NewPara 'Figure 4. Use Case Diagram' $true;[void]$usePic.ParentNode.InsertAfter($useCaption,$usePic)
 Put (Prefix 'Figure 4 presents') 'Figure 4 summarizes actor participation in the nine main functional areas of IronGrind: User Login, Membership Application, User Management, Renewals, QR Attendance, Product & Inventory, Sales, Generate Reports, and Activity Logs. The rectangle identifies the system boundary, the ovals identify function-level capabilities, and the labeled external icons identify Member / Applicant, Authorized Staff, and Administrator. An association indicates that an actor participates in a functional area; the accompanying role descriptions specify the actions available within it. The figure therefore provides an overview of responsibilities without granting every connected actor the same permissions.'
 $erdHeading=One 'Entity Relationship Diagram';$erdPic=ImageAfter $erdHeading;ReplaceImage $erdPic '05-gym-erd-editable' 9
 $erdCaption=NewPara 'Figure 5. Public-schema Entity Relationship Diagram' $true;[void]$erdPic.ParentNode.InsertAfter($erdCaption,$erdPic)
 $explanations=@(
 'Figure 5 presents the public-schema relationship overview for IronGrind. It contains twelve public application tables and the eighteen foreign-key relationships declared on those tables. The auth.users card represents a referenced Supabase-managed identity table and is not counted as an application-owned public table. Selected key and descriptive attributes are shown to keep the overview manageable; the data dictionary that follows provides the complete documented field definitions.',
 'The central membership records connect account identity, applications, current membership, visits, transactions, and membership history. A membership application can refer to an existing member when the request concerns that member. Conversely, the optional unique members.application_id identifies the application from which a member record originated. These are separate foreign keys with different purposes: one member may have multiple requests, while a particular source application can be linked to at most one member through the unique source-application field. Walk-in members do not require an online source application.',
 'Attendance records belong to members and retain the identities of the operators who recorded check-in and check-out. Sales headers may refer to members and identify the processing account, while sale_items provides the itemized lines of a sale and any associated product reference. Membership history preserves recorded membership changes. Scanner-session and scan-event tables describe paired attendance communication, and the pairing-policy table records the configured capacity policy. The activity_logs table is shown without an invented foreign-key relationship: an actor identifier recorded in a log is not, by itself, evidence of a declared database constraint.',
 'PK identifies a primary key, FK a foreign key, and UQ an individually unique key. In crow-foot notation, a circle means zero is permitted, a bar denotes one, and the fork denotes many; the endpoint symbols must be read together. Solid connectors link the public application tables. Dashed blue-gray connectors identify references to managed authentication identities; this line style is a visual grouping choice and does not imply weaker referential enforcement. A line crossing does not create a relationship.',
 'This figure intentionally covers the public schema rather than the entire application-owned database. The documented full model contains twenty-one application tables, 224 fields, and thirty-three declared foreign keys: twelve public tables and nine private supporting tables. The private structures support attendance requests, login attempts, scoped account sessions, and administrator/member device authorization. Their definitions remain in the data dictionary and separate security reference materials. The overview describes stored relationships, not role permissions or proof of production deployment; its schema baseline comes from the supplied export and checked-in migrations rather than a new live-database inspection.'
 )
 $anchor=$erdCaption;foreach($value in $explanations){$p=NewPara $value;[void]$anchor.ParentNode.InsertAfter($p,$anchor);$anchor=$p}
 Landscape $erdHeading $erdCaption
 $ganttHeading=One 'Gantt Chart';$ganttPic=ImageAfter $ganttHeading;ReplaceImage $ganttPic '33-gantt' 8.8;$ganttCaption=One 'Figure 33. Gantt Chart';Landscape $ganttHeading $ganttCaption
 Put (Prefix 'The Gantt chart presents') 'Figure 33 presents the original ten-week planned development schedule for IronGrind, from August 24 to October 28, 2026. The left columns identify each activity and its planned date range, while W1 to W10 identify the ten scheduled weeks. Planning occupies Weeks 1–4 and consists of identifying a potential client, conducting the first client interview to identify problems and needs, project conceptualization, and drafting the proposal. Design occupies Weeks 5–8 and covers interface design, prototype development, client feedback, and refinement. Development occupies Weeks 9–10 and covers the planned start and continuation of frontend, backend, database, API, and supporting work alongside the project chapters. The planning activities follow the clarification supplied by the proponents; the existing date ranges are retained as schedule assignments and do not independently establish actual completion dates.'
 Put (Prefix 'The horizontal timeline indicates') 'Each colored bar locates an activity within its assigned planned week. The chart does not record actual completion, measured effort, evaluation outcomes, or production readiness. Its three phase groups organize the original schedule, while the Agile methodology describes how development and refinement can repeat within and beyond that plan. Later repository revisions and deployment evidence must be reported separately rather than retroactively treated as work completed within the original ten weeks.'
 if($tablesBefore -cne ((@($doc.SelectNodes('//w:tbl',$ns)|ForEach-Object OuterXml))-join '')){throw 'A dictionary or requirements table changed'}
 if($dfdBefore -cne (Between $dfdStart $dfdEnd)){throw 'DFD content changed'}
 if($agileBefore -cne ((@($doc.SelectNodes('//w:body/w:p',$ns))[0..24]|ForEach-Object OuterXml)-join '')){throw 'Agile or opening material changed'}
 $entry=$zip.GetEntry('word/document.xml');$entry.Delete();$stream=$zip.CreateEntry('word/document.xml').Open();$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));$doc.Save($writer);$writer.Dispose()
 # Every other package part, including Agile, DFD and prototype image bytes, must stay unchanged.
 $original=[IO.Compression.ZipFile]::OpenRead($backup)
 try{foreach($old in $original.Entries){if($old.FullName -eq 'word/document.xml' -or $changedParts.Contains($old.FullName)){continue};$current=$zip.GetEntry($old.FullName);if(-not $current){throw "Removed package part: $($old.FullName)"};$sha=[Security.Cryptography.SHA256]::Create();$os=$old.Open();$cs=$current.Open();try{if([Convert]::ToBase64String($sha.ComputeHash($os)) -ne [Convert]::ToBase64String($sha.ComputeHash($cs))){throw "Unexpected changed package part: $($old.FullName)"}}finally{$os.Dispose();$cs.Dispose();$sha.Dispose()}}}finally{$original.Dispose()}
} finally {$zip.Dispose()}
Copy-Item -LiteralPath $work -Destination $source -Force
'Updated Chapter 3: captions, context, public ERD scope/legend, original-plan Gantt, and explanations. All tables, Agile/DFD paragraphs and unrelated package parts preserved.'
