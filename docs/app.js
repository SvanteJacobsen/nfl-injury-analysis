'use strict';

const $ = (selector) => document.querySelector(selector);
const tooltip = $('#chart-tooltip');
const nf = new Intl.NumberFormat('en-US');
const positionData = [
  {code:'DB',name:'Defensive Back',count:441,share:7.1},
  {code:'TE',name:'Tight End',count:138,share:6.2},
  {code:'WR',name:'Wide Receiver',count:234,share:5.5},
  {code:'QB',name:'Quarterback',count:67,share:4.9},
  {code:'OL',name:'Offensive Line',count:249,share:4.5},
  {code:'LB',name:'Linebacker',count:192,share:4.3},
  {code:'RB',name:'Running Back',count:112,share:4.3},
  {code:'DL',name:'Defensive Line',count:121,share:2.4},
  {code:'K/P/LS',name:'Kicker / Punter / Long Snapper',count:7,share:0.5}
];
const categories = [['knee',10216],['ankle',7997],['hamstring',5134],['shoulder',5038],['concussion',2874],['foot',2490],['groin',2392],['back',2192],['hip',1872],['calf',1760]];
const escapeHTML = (value) => String(value).replace(/[&<>"']/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const formatChange = (current,previous) => previous > 0 ? `${current>previous?'+':current<previous?'−':''}${Math.abs((current/previous-1)*100).toFixed(1)}%` : 'N/A';
const periodName = {regular:'Regular season',preseason:'Preseason',total:'Total'};
let seasons = [];
let selectedSeason = 2024;
let positionMetric = 'share';

function showTooltip(html, x, y) {
  tooltip.innerHTML=html; tooltip.hidden=false;
  const box=tooltip.getBoundingClientRect();
  tooltip.style.left=`${Math.max(10,Math.min(x+14,innerWidth-box.width-12))}px`;
  tooltip.style.top=`${Math.max(10,Math.min(y+16,innerHeight-box.height-12))}px`;
}
function bindTooltips(root) {
  root.querySelectorAll('[data-tip]').forEach((el)=>{
    el.addEventListener('pointerenter',(event)=>showTooltip(el.dataset.tip,event.clientX,event.clientY));
    el.addEventListener('pointermove',(event)=>showTooltip(el.dataset.tip,event.clientX,event.clientY));
    el.addEventListener('pointerleave',()=>tooltip.hidden=true);
    el.addEventListener('focus',()=>{const b=el.getBoundingClientRect();showTooltip(el.dataset.tip,b.x+b.width/2,b.y+b.height/2);});
    el.addEventListener('blur',()=>tooltip.hidden=true);
  });
}
document.addEventListener('keydown',(e)=>{if(e.key==='Escape')tooltip.hidden=true;});
document.addEventListener('scroll',()=>tooltip.hidden=true,{passive:true});

function lineChart(target, values, {title,format=(v)=>nf.format(v),unit,extras,firstLabelOffset=0}={}) {
  const root=$(target), w=960,h=290,p={l:48,r:44,t:30,b:32};
  const valid=values.filter(v=>v!==null&&Number.isFinite(v));
  if(!valid.length){root.textContent='No data available for this period.';return;}
  let lo=Math.min(...valid),hi=Math.max(...valid);
  const range=(hi-lo)||Math.max(hi,1)*.3;
  const step=Math.pow(10,Math.floor(Math.log10(range/4)));
  const raw=range/4/step,interval=(raw<=1?1:raw<=2?2:raw<=2.5?2.5:raw<=5?5:10)*step;
  lo=Math.max(0,Math.floor((lo-range*.06)/interval)*interval);
  hi=Math.ceil((hi+range*.08)/interval)*interval;
  if(hi===lo)hi=lo+interval;
  const x=(i)=>p.l+i*(w-p.l-p.r)/(values.length-1),y=(v)=>p.t+(hi-v)/(hi-lo)*(h-p.t-p.b);
  const ticks=[];for(let v=lo;v<=hi+interval*.1;v+=interval)ticks.push(v);
  let svg=`<svg viewBox="0 0 ${w} ${h}" role="img" aria-label="${escapeHTML(title)}"><title>${escapeHTML(title)}</title><desc>${escapeHTML(seasons.map((r,i)=>`${r.year}: ${values[i]===null?'not available':format(values[i])}`).join('; '))}</desc>`;
  ticks.forEach(v=>{svg+=`<line x1="${p.l}" x2="${w-p.r}" y1="${y(v)}" y2="${y(v)}" stroke="#e8edf3" stroke-width="1"/><text x="${p.l-10}" y="${y(v)+4}" text-anchor="end">${format(v)}</text>`;});
  let path='';values.forEach((v,i)=>{if(v===null){path+=' ';return;}path+=`${i===0||values[i-1]===null?'M':'L'}${x(i).toFixed(2)},${y(v).toFixed(2)} `;});
  svg+=`<path d="${path}" fill="none" stroke="#0074ee" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`;
  seasons.forEach((r,i)=>{
    svg+=`<text x="${x(i)}" y="${h-7}" text-anchor="middle">${r.year}</text>`;
    if(values[i]===null)return;
    const prev=i?values[i-1]:null;
    const change=prev>0?formatChange(values[i],prev):'N/A';
    const tip=`<strong>${r.year} season</strong><br>${escapeHTML(unit)}: <b>${format(values[i])}</b><br>Change vs previous season: ${change}${extras?`<small>${escapeHTML(extras(r))}</small>`:''}`;
    const label=`${r.year}: ${format(values[i])} ${unit}. Change ${change}`;
    if(r.year===selectedSeason)svg+=`<circle cx="${x(i)}" cy="${y(values[i])}" r="5.5" fill="#0074ee" stroke="white" stroke-width="2"/>`;
    if(i===0||i===values.length-1)svg+=`<text class="point-label" x="${x(i)+(i===0?firstLabelOffset:0)}" y="${y(values[i])-14}" text-anchor="middle">${format(values[i])}</text>`;
    svg+=`<circle cx="${x(i)}" cy="${y(values[i])}" r="14" fill="transparent" tabindex="0" role="img" aria-label="${escapeHTML(label)}" data-tip="${escapeHTML(tip)}"/>`;
  });
  root.innerHTML=svg+'</svg>';bindTooltips(root);
}

function renderAnnual() {
  lineChart('#total-chart',seasons.map(r=>r.total),{title:'Reported NFL concussions, 2015–2024',unit:'Concussions',extras:()=> 'Preseason and regular-season games and practices.'});
  const gamePeriod=$('#game-period').value;
  const games=(r)=>gamePeriod==='regular'?r.regGames:gamePeriod==='preseason'?r.preGames:r.regGames+r.preGames;
  const events=(r)=>gamePeriod==='regular'?r.regGame:gamePeriod==='preseason'?r.preGame:r.regGame+(r.preGame??0);
  $('#game-subtitle').textContent=`${periodName[gamePeriod]} · 2015–2024`;
  lineChart('#game-chart',seasons.map(r=>games(r)>0&&events(r)!==null?events(r)/games(r):null),{title:`${periodName[gamePeriod]} concussions per game, 2015–2024`,unit:'Concussions per game',format:v=>v.toFixed(2),extras:r=>`${events(r)} reported game concussions · ${games(r)} games. Includes both teams; excludes practices and playoffs.`});
  const practicePeriod=$('#practice-period').value;
  $('#practice-subtitle').textContent=`${periodName[practicePeriod]} · 2015–2024`;
  lineChart('#practice-chart',seasons.map(r=>practicePeriod==='regular'?r.regPractice:practicePeriod==='preseason'?r.prePractice:r.regPractice+r.prePractice),{title:`${periodName[practicePeriod]} practice concussions, 2015–2024`,unit:'Practice concussions',firstLabelOffset:12,extras:()=> 'Reported events, not unique players. Practice exposure is unavailable.'});
}
function renderKPIs() {
  const i=seasons.findIndex(r=>r.year===selectedSeason),r=seasons[i],p=seasons[i-1];
  const get={total:x=>x.total,games:x=>x.regGame+(x.preGame??0),practice:x=>x.regPractice+x.prePractice};
  for(const [key,fn] of Object.entries(get)){
    $(`#kpi-${key}`).textContent=nf.format(fn(r));
    const delta=$(`#delta-${key}`);delta.textContent=p?formatChange(fn(r),fn(p)):'N/A';
    delta.className=!p||fn(r)===fn(p)?'neutral':fn(r)>fn(p)?'increase':'';
  }
}
function renderCategories() {
  const root=$('#category-chart'),max=categories[0][1];
  root.innerHTML=categories.map(([label,count],i)=>`<div class="bar-row ${label==='concussion'?'concussion':''}" tabindex="0" role="img" aria-label="${label}, ${nf.format(count)} player-week reports, rank ${i+1}" data-tip="${escapeHTML(`<strong>${label}</strong><br>${nf.format(count)} player-week reports<br>Rank: ${i+1}<small>2015–2025 · Regular season. Repeated weekly reports may concern the same injury.</small>`)}"><span class="bar-label">${label}</span><div class="bar-track" style="--bar-width:${count/max*100}%"><span class="bar-fill"></span><span class="bar-value">${nf.format(count)}</span></div></div>`).join('');
  bindTooltips(root);
}
function renderPositions() {
  const rows=[...positionData].sort((a,b)=>b[positionMetric]-a[positionMetric]),max=rows[0][positionMetric],root=$('#position-chart');
  $('#position-subtitle').textContent=`${positionMetric==='share'?'Share of each position group':'Player-seasons with concussion reports'} · Regular season · 2015–2025`;
  root.innerHTML=rows.map(r=>{
    const value=positionMetric==='share'?r.share.toFixed(1)+'%':nf.format(r.count);
    const tip=`<strong>${r.code} — ${r.name}</strong><br>Player-seasons with concussion reports: ${nf.format(r.count)}<br>Share of position group: ${r.share.toFixed(1)}%<small>2015–2025 · Each player counted once per position group and season. Shares displayed to one decimal.</small>`;
    return `<div class="bar-row" tabindex="0" role="img" aria-label="${escapeHTML(`${r.name}: ${value}`)}" data-tip="${escapeHTML(tip)}"><span class="bar-label">${r.code}</span><div class="bar-track" style="--bar-width:${r[positionMetric]/max*100}%"><span class="bar-fill"></span><span class="bar-value">${value}</span></div></div>`;
  }).join('');bindTooltips(root);
}

async function init() {
  renderCategories();renderPositions();
  document.querySelectorAll('[data-trend-metric]').forEach(button=>button.addEventListener('click',()=>{
    const share=button.dataset.trendMetric==='share';
    document.querySelectorAll('[data-trend-metric]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
    $('#position-trend-chart').innerHTML=share
      ? '<img src="assets/position-trend-share.png" width="1891" height="1170" alt="Concussion reports by position over time, share, regular season 2015-2025">'
      : '<img src="assets/position-trend-count.png" width="1891" height="1169" alt="Concussion reports by position over time, count, regular season 2015-2025">';
  }));

  try{
    const response=await fetch('data.json');if(!response.ok)throw new Error('Data unavailable');
    seasons=await response.json();
    $('#season-select').innerHTML=[...seasons].reverse().map(r=>`<option value="${r.year}">${r.year}</option>`).join('');
    $('#season-select').value=String(selectedSeason);renderKPIs();renderAnnual();
    $('#season-select').addEventListener('change',(e)=>{selectedSeason=Number(e.target.value);renderKPIs();renderAnnual();});
    $('#game-period').addEventListener('change',renderAnnual);$('#practice-period').addEventListener('change',renderAnnual);
  }catch(error){
    ['#total-chart','#game-chart','#practice-chart'].forEach(id=>$(id).innerHTML='<p>Chart data could not be loaded. Please reload the page, or explore the full Tableau dashboard below.</p>');
    $('#season-select').disabled=true;
  }
  document.querySelectorAll('[data-metric]').forEach(button=>button.addEventListener('click',()=>{
    positionMetric=button.dataset.metric;
    document.querySelectorAll('[data-metric]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));renderPositions();
  }));
}
const chapterLinks=[...document.querySelectorAll('.chapter-nav a')];
const chapters=chapterLinks.map(a=>document.querySelector(a.getAttribute('href')));
let ticking=false;
function updateScroll(){
  const max=document.documentElement.scrollHeight-innerHeight;
  $('.reading-progress span').style.width=`${max>0?scrollY/max*100:0}%`;
  let index=0;chapters.forEach((section,i)=>{if(section.getBoundingClientRect().top<180)index=i;});
  chapterLinks.forEach((link,i)=>{link.classList.toggle('active',i===index);if(i===index)link.setAttribute('aria-current','location');else link.removeAttribute('aria-current');});
  ticking=false;
}
addEventListener('scroll',()=>{if(!ticking){requestAnimationFrame(updateScroll);ticking=true;}},{passive:true});
addEventListener('resize',updateScroll);updateScroll();init();
