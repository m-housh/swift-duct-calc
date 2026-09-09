/* Reference-table adapters for the checked-in fitting data. Not audited calculation rules. */
(()=>{
'use strict';
const data=window.FITTINGS;
const pretty=s=>({hardBend:'Hard bend',hOverW1:'H/W = 1',easyBend:'Easy bend',withoutVanes:'Without vanes',withVanes:'With vanes',mitered:'Mitered','rEquals0.25':'R = 0.25 (source)','rGreaterThan0.50':'R > 0.50 (source)',miter:'Mitered heel',radius:'Radius heel'}[s]||String(s));
function table(f,labels,rows){
 f.rule={kind:'table',labels,rows:rows.filter(r=>Number.isFinite(r.value))};
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
// Only the box-only sidewall table is displayed by the reference.
// The picker owns dimension inputs, evaluation, and optional bend calculations.
for (const f of data.filter(f => f.concept === 'junction-box')) {
 table(f, ['Box velocity (FPM)', 'Openings'], [[400,20],[500,30],[600,40],[700,60],[800,75],[900,95]]
  .map(([velocity,value]) => ({keys:[String(velocity),'Sidewall · box only'],value})));
}
})();
