/* Prototype adapters for the supplied artwork manifests. Exact source rows only. */
(()=>{
'use strict';
const data=window.FITTINGS;
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const pretty=s=>({hardBend:'Hard bend',hOverW1:'H/W = 1',easyBend:'Easy bend',withoutVanes:'Without vanes',withVanes:'With vanes',mitered:'Mitered','rEquals0.25':'R = 0.25 (source)','rGreaterThan0.50':'R > 0.50 (source)',miter:'Mitered heel',radius:'Radius heel'}[s]||String(s));
const result=(value,note)=>({value:Number.isFinite(value)?value:null,note});
function table(f,labels,rows){
 f.rule={kind:'table',labels,rows:rows.filter(r=>Number.isFinite(r.value))};
 f.rule.options=labels.map((_,i)=>[...new Set(f.rule.rows.map(r=>String(r.keys[i])))]);
}
function mapRule(f,label,map){table(f,[label],Object.entries(map).map(([k,value])=>({keys:[pretty(k)],value})));}
for(const f of data){
 const v=f.values;
 if(f.concept)continue;
 const ratio=f.ratioTable||v.equivalentLengthByRatio;
 if(ratio){f.rule={kind:'ratio',...ratio};continue;}
 if(f.branches){table(f,['Downstream branches'],f.branches.map(r=>({keys:[r.branchCountMax===null?r.branchCountMin+'+':String(r.branchCountMin)],value:r.feet})));continue;}
 if(f.fixed!==undefined)continue;
 if(v.equivalentLengthByReturnCount){table(f,['Returns entering this plenum'],v.equivalentLengthByReturnCount.map(r=>({keys:[r.returnCountMin?r.returnCountMin+'+':String(r.returnCount)],value:r.feet})));continue;}
 if(v.ratioParameter){table(f,[v.ratioParameter,'Path through this junction'],v.rows.flatMap(r=>['branch','trunk'].map(p=>({keys:[String(r.ratio),p==='branch'?'Branch':'Trunk'],value:r[p+'EquivalentLengthFeet']}))));continue;}
 if(v.equivalentLengthByCfm){table(f,['Airflow in this space (CFM)'],v.equivalentLengthByCfm.map(r=>({keys:[String(r.cfm)],value:r.feet+(f.adjustment?.feet||0),note:f.adjustment?`${r.feet} ft + ${f.adjustment.feet} ft for merging flow`:''})));continue;}
 if(v.branchEquivalentLengthFeet!==undefined){table(f,['Path through this junction'],['branch','main'].map(p=>({keys:[p==='branch'?'Branch':'Main'],value:v[p+'EquivalentLengthFeet']})));continue;}
 if(v.radiusRatioValues){table(f,['R/D'],v.radiusRatioValues.map(r=>({keys:[r.rOverDMinimum?'≥ '+r.rOverDMinimum:String(r.rOverD)],value:r.feet})));}
 else if(v.radiusRatioTable||v.table){const t=v.radiusRatioTable||v.table;table(f,[v.table?'H/L':'R/W','Construction'],t.rows.flatMap(r=>t.columns.map((c,i)=>({keys:[String(r.hOverL??r.rOverW??('≥ '+r.rOverWMinimum)),pretty(c)],value:r.feet[i]}))));}
 else if(v.equivalentLengthByRiser){table(f,['Riser dimensions (in)','Heel'],Object.entries(v.equivalentLengthByRiser).flatMap(([size,heels])=>Object.entries(heels).map(([h,value])=>({keys:[size.replace('x',' × '),pretty(h)],value}))));}
 else if(v.singleElbowEquivalentLengthMultiplier){f.rule={kind:'composite',multiplier:v.singleElbowEquivalentLengthMultiplier};}
 else if(v.inletVelocityFpm){table(f,['Inlet velocity (FPM)','Outlet velocity (FPM)'],v.inletVelocityFpm.flatMap((a,i)=>v.outletVelocityFpm.map((b,j)=>({keys:[String(a),String(b)],value:v.equivalentLengthFeetByOutletThenInlet[j][i]}))));}
 else if(v.largerToSmallerAreaRatios){
  const axis=v.slopes||v.velocityFpm||[v.slope];
  table(f,[v.velocityFpm?'Velocity (FPM)':'Slope X/Y','Larger / smaller area'],axis.flatMap((a,i)=>v.largerToSmallerAreaRatios.map((b,j)=>({keys:[String(a),String(b)],value:axis.length===1?v.equivalentLengthFeet[j]:v.equivalentLengthFeet[i][j],note:v.minimumUpstreamStaticPressureIwc?`Minimum upstream static pressure ${v.minimumUpstreamStaticPressureIwc[i][j]} IWC; ${v.staticPressureNote}`:''}))));
 }
 else{
  const mapKeys={equivalentLengthByPieceCount:'Piece count',equivalentLengthByAspect:'Bend aspect',equivalentLengthByLOverH:'L/H',equivalentLengthByROverH:'R/H',equivalentLengthByInsideRadius:'Inside radius'};
  for(const [key,label]of Object.entries(mapKeys))if(v[key])mapRule(f,label,v[key]);
 }
 if(v.angleMultipliers&&f.rule?.kind==='table'){
  // Preserve the explicit 90° base. Conflicting >90° source heading is unresolved.
  const angles={'90':1,...Object.fromEntries(Object.entries(v.angleMultipliers).filter(([a])=>Number(a)<90))};
  table(f,[...f.rule.labels,'Bend angle (degrees)'],f.rule.rows.flatMap(r=>Object.entries(angles).map(([a,m])=>({keys:[...r.keys,a],value:r.value*m,note:`${r.value} ft at 90° × ${m}`}))));
 }
}
// Compound elbows derive their base from another supported 90° elbow, never typed EL.
for(const f of data.filter(f=>f.rule?.kind==='composite')){
 const rows=[];
 for(const base of data.filter(b=>f.shape==='round'?['8A-smooth','8A-4-or-5-piece','8A-3-piece','8A-mitered'].includes(b.id):['8B','8C','8D','8E'].includes(b.id))){
  const baseRows=base.fixed!==undefined?[{keys:[],value:base.fixed}]:base.rule.rows.filter(r=>!base.rule.labels.includes('Bend angle (degrees)')||r.keys.at(-1)==='90');
  for(const r of baseRows)rows.push({keys:[`${base.code} · ${base.name}${r.keys.length?' · '+r.keys.join(' / '):''}`],value:r.value*f.rule.multiplier,note:`Base elbow ${base.id}: ${r.value} ft × ${f.rule.multiplier}`});
 }
 table(f,['Single 90° elbow construction and source dimensions'],rows);
}
const velocity=[400,500,600,700,800,900],box=[20,30,40,60,75,95],bend=[[5,5,5,5],[5,5,5,5],[10,5,5,5],[15,10,5,5],[15,10,10,8],[20,15,10,8]],radii=['1.0','1.5','2–3','4–5'];
function calculate(f,d){
 if(f.concept){
  const i=velocity.indexOf(Number(d.velocity));
  if(i<0)return result(null,'Choose an exact velocity row from the supplied PDF.');
  if(d.openings!=='sidewall')return result(null,'The supplied box table covers sidewall openings. No automatic length is available for top or bottom openings.');
  if(d.withBend!=='yes')return result(box[i],`Box only: ${box[i]} ft · reference velocity ${d.velocity} FPM`);
  const j=radii.indexOf(d.radius),bendIndex=velocity.indexOf(Number(d.bendVelocity));
  if(bendIndex<0||j<0)return result(null,`Box: ${box[i]} ft. Choose the supplied 90° bend’s velocity and R/D to complete this entry.`);
  const bendFeet=bend[bendIndex][j];
  return result(box[i]+bendFeet,`Box ${box[i]} ft + supplied 90° radius bend ${bendFeet} ft = ${box[i]+bendFeet} ft · box ${d.velocity} FPM · bend ${d.bendVelocity} FPM · R/D ${d.radius}`);
 }
 if(f.fixed!==undefined)return result(f.fixed,'Prescribed reference value');
 if(f.rule?.kind==='ratio'){
  const a=Number(d.numerator),b=Number(d.denominator),ratio=a/b;
  if(!(a>0&&b>0&&Number.isFinite(a)&&Number.isFinite(b)))return result(null,'Enter both dimensions marked on the drawing.');
  const r=f.rule.rows.find(r=>Math.abs(r.ratio-ratio)<1e-9);
  return result(r?.feet,`${f.rule.parameter} = ${Number(ratio.toFixed(4))}${r?'':' · No exact source row. Interpolation has not been established.'}`);
 }
 if(f.rule?.kind==='table'){
  const row=f.rule.rows.find(r=>r.keys.every((k,i)=>String(k)===d['choice'+i]));
  return result(row?.value,row?row.keys.map((k,i)=>f.rule.labels[i]+': '+k).join(' · ')+(row.note?' · '+row.note:''):'Choose the required source conditions. A blank table combination has no supported value.');
 }
 return result(null,'Artwork available; this calculation still needs a source rule.');
}
function select(d,key,label,options){return `<label>${esc(label)}<select data-field="${key}"><option value="">Choose…</option>${options.map(o=>{const value=typeof o==='object'?o.value:o,label=typeof o==='object'?o.label:o;return `<option value="${esc(value)}" ${d[key]===String(value)?'selected':''}>${esc(label)}</option>`}).join('')}</select></label>`;}
function number(d,key,label){return `<label>${esc(label)}<input data-field="${key}" type="number" min="0.01" step="any" value="${esc(d[key]||'')}"></label>`;}
function fields(f,d){
 if(f.concept){
  const toggle=`<label class="bend-toggle"><input type="checkbox" role="switch" data-field="withBend" ${d.withBend==='yes'?'checked':''}><span>Supplied with a 90° radius bend<small>Include one bend with this junction box.</small></span></label>`;
  const bendInputs=`<section class="supplied-bend" ${d.withBend==='yes'?'':'hidden'} aria-label="Supplied 90 degree radius bend"><img src="concepts/11-radius-bend.svg" alt="Supplied 90 degree radius bend with radius R and duct diameter D"><h4>Supplied 90° radius bend</h4>${select(d,'bendVelocity','Velocity in the supplied bend (FPM)',velocity)}${select(d,'radius','Bend radius / duct diameter · R/D',radii)}<small>The bend contributes to this box entry. Use its own duct velocity; the angle is fixed at 90°.</small></section>`;
  return toggle+bendInputs+select(d,'velocity','Velocity in flex duct (FPM)',velocity)+select(d,'openings','Entrance or exits',[{value:'sidewall',label:'Sidewall'},{value:'top-bottom',label:'Top or bottom'}])+'<div class="box-guidance"><strong>ASSUMES:</strong><ul><li>Straight approach and departure</li><li>First outlet at L ≥ 2 × D</li></ul><p>A nearby bend or closer outlet may make the listed loss too small.</p></div><small>Count the box once for this path. The optional 90° bend adds to its length, not its quantity.</small>';
 }
 if(f.rule?.kind==='ratio'){
  const [a,b]=f.rule.parameter.split('/');return `<div class="fields">${number(d,'numerator',a+' (in)')}${number(d,'denominator',b+' (in)')}</div><small>Source ratios: ${f.rule.rows.map(r=>r.ratio).join(', ')}. Exact matches only.</small>`;
 }
 if(f.rule?.kind==='table')return f.rule.labels.map((l,i)=>select(d,'choice'+i,l,f.rule.options[i])).join('')+(f.countingRule?`<small>${esc(f.countingRule)}</small>`:'');
 return '';
}
function reference(f){const c=f.conditions;return `<details class="source-details"><summary>Reference & conditions</summary><p><a href="/files/ManD.Groups.pdf#page=${f.source.pdfPage||f.source.pdfPages?.[0]||1}" target="_blank" rel="noopener">Open supplied PDF · printed page ${esc(f.page)}</a></p><p>${esc(c.velocityFpm??'See source')} FPM · ${esc(c.frictionRateIwcPer100Feet??.08)} IWC / 100 ft</p>${[...f.notes,...Object.entries(c).filter(([k])=>!['velocityFpm','frictionRateIwcPer100Feet'].includes(k)).map(([,v])=>v)].map(n=>`<p>${esc(n)}</p>`).join('')}${f.concept?'<p>Concept illustration for review. Values follow the supplied PDF. Source case names are descriptive; they are not fittings 11A or 11B.</p>':''}</details>`;}
function label(f){return f.concept?f.name:f.code;}
function subtitle(f){return [f.variant,f.shape,f.view].filter(Boolean).filter((x,i,a)=>a.indexOf(x)===i).join(' · ').replaceAll('-',' ');}
window.CatalogRules={calculate,fields,reference,label,subtitle};
})();
