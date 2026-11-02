// Offline UI / UX prototype: identity, messages, and accounting are isolated demos reset on reload.
const offers=[{id:'labor',name:'给书架来次大整理',kind:'现实劳动',reward:800,steps:['把同类书放在一起','摆整齐，书脊朝外','做完后提交给家长检查']},{id:'learn',quick:true,quickName:'学习',icon:'quick-study',name:'自己选一本书，分享新发现',kind:'主动学习',reward:500,steps:['和家长提前约好：自主阅读 20 分钟','分享一个自己感兴趣的发现','家长检查并按约定兑现奖励']},{id:'extra',name:'帮忙给阳台的小花浇水',kind:'临时小任务',reward:300,steps:['先问清哪几盆需要浇水','按约定用水量完成','提交给家长检查']},
{id:'dishes',quick:true,quickName:'洗碗',icon:'quick-dishes',name:'洗碗',kind:'现实劳动',reward:200,steps:['洗好事先约定的碗筷','冲洗干净并摆好','收拾水槽后提交给家长检查']},
{id:'mop',quick:true,quickName:'拖地',icon:'quick-mop',name:'拖地',kind:'现实劳动',reward:300,steps:['按约定整理要拖的地面','拖好约定区域','工具归位后提交给家长检查']},
{id:'toys',quick:true,quickName:'整理玩具',icon:'quick-toys',name:'整理玩具',kind:'现实劳动',reward:200,steps:['把玩具按类别收好','放回约定的收纳位置','收拾好地面后提交给家长检查']},
{id:'vegetables',quick:true,quickName:'摘菜',icon:'quick-vegetables',name:'摘菜',kind:'现实劳动',reward:100,steps:['和家长确认要整理的蔬菜','按约定摘好、分好','整理台面后提交给家长检查']}];
const wishes=[{id:'gift',name:'我的第一台望远镜',target:8000,label:'礼物心愿'},{id:'save',name:'攒到我的第一个 200 元',target:20000,label:'攒钱目标'}];

const profiles = [{id:'li',name:'小栗',cash:3200},{id:'tao',name:'小桃',cash:0}];
const initial = (cash=3200) => ({
  child:{cash,holding:0}, parent:{cash,holding:0}, wish:'gift',
  wishes:wishes.map(w=>({...w})), tasks:Object.fromEntries(offers.map(o=>[o.id,'available'])),
  requests:[], receipts:[], notes:{}, events:[`独立示例：已有 ${cash/100} 元，不使用真实家庭数据。`], seq:0
});
let family=Object.fromEntries(profiles.map(p=>[p.id,initial(p.cash)]));
let activeChild='li', data=family.li, role='child';
const params=new URLSearchParams(location.search);
let mode=params.get('device')==='phone'?'phone':'tablet';
let childPage='home', parentPage='inbox', taskFilter='all', modal=null, selectedTask='labor', timer;
let returnFocus=null, wishDraft={name:'',target:'',type:'gift'}, errors={}, revisionDraft='';
const fulfilledRequests=new Set();
const amount=n=>(n/100).toFixed(2);
const whole=n=>Number.isInteger(n/100)?String(n/100):amount(n);
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const image=(n,c='')=>`<img src="${ASSETS[n]}" class="${c}" alt="">`;
const icon=name=>atob(ASSETS['icon-'+name].split(',')[1]).replace('<svg ','<svg class="icon" ').replace(/#667357/g,'currentColor');
const profile=()=>profiles.find(p=>p.id===activeChild);
const getWish=()=>data.wishes.find(w=>w.id===data.wish);
const total=side=>data[side].cash+data[side].holding;
const pendingCount=()=>data.requests.filter(r=>!r.done).length;
const phaseText={available:'可以接取',accepted:'现实中行动',revision:'还有一点，改好再提交',queued:'待发送给家长',delivered:'待家长检查',checked:'检查通过，待实际兑现',paid:'家长已兑现，等接收记录',received:'这次收获已记好'};
const quickStatus={available:'做好点我',accepted:'做好点我',revision:'需要再试试',queued:'待发送',delivered:'待家长确认',checked:'待兑现',paid:'待接收记录',received:'今天已完成'};
function addEvent(e){data.events.push(e);}
function toast(text,undoTask=null){
  clearTimeout(timer);
  document.getElementById('toast-root').innerHTML=`<div class="toast" role="status"><span>${esc(text)}</span>${undoTask?`<button data-withdraw="${undoTask}">撤回</button>`:''}</div>`;
  timer=setTimeout(()=>document.getElementById('toast-root').innerHTML='',undoTask?8000:4200);
}
function clearToast(){clearTimeout(timer);document.getElementById('toast-root').innerHTML='';}
function request(kind,taskId=null){
  if(data.requests.some(r=>r.kind===kind&&r.taskId===taskId&&!r.done))return;
  data.requests.push({id:`${activeChild}-demo-${++data.seq}`,kind,taskId,delivered:false,done:false});
  addEvent(`${kind==='task'?offers.find(t=>t.id===taskId).name:kind==='invest'?'存入10元请求':'预支提议'}：待发送，未入账。`);
}
function quickTasks(){
  return `<section class="section quick-section"><div class="section-title"><h2>做好了，点一下</h2><small>提交给家长确认</small></div><div class="quick-grid">${['dishes','mop','toys','vegetables','learn'].map(id=>{
    const t=offers.find(o=>o.id===id),phase=data.tasks[id],pending=['queued','delivered','checked','paid'].includes(phase),done=phase==='received';
    return `<button class="quick-task ${pending?'pending':''} ${done?'done':''}" data-quick="${id}" aria-label="${t.quickName}，约定${whole(t.reward)}元，${quickStatus[phase]}${['available','accepted'].includes(phase)?'，点击提交给家长':''}">${done?`<span class="done-badge">${icon('check')}</span>`:''}<span class="quick-icon">${image(t.icon)}</span><b>${t.quickName}</b><small>约定 ${whole(t.reward)} 元</small><span class="quick-status">${quickStatus[phase]}</span></button>`;
  }).join('')}</div><p class="quick-help">${icon('info')}现实中做好再点。家长兑现后，零钱才会增加。</p></section>`;
}
function quickSubmit(id){
  if(role!=='child')return;
  const t=offers.find(o=>o.id===id);if(!t?.quick)return;
  if(!['available','accepted'].includes(data.tasks[id])){open('task',id);return;}
  selectedTask=id;data.tasks[id]='queued';request('task',id);modal=null;render();
  document.querySelector(`[data-quick="${id}"]`)?.focus({preventScroll:true});
  toast(`${t.quickName}已提交，等待送达家长。零钱还没有变化。`,id);
}
function withdrawSubmission(id){
  if(role!=='child'||!['queued','delivered'].includes(data.tasks[id]))return;
  const r=data.requests.find(r=>r.kind==='task'&&r.taskId===id&&!r.done);if(!r)return;
  r.done=true;r.cancelled=true;data.tasks[id]='available';
  addEvent('孩子撤回：'+offers.find(o=>o.id===id).name+'，未入账。');modal=null;render();
  toast('已撤回，零钱没有变化。');
}
function navigation(isMobile=false){
  const items=role==='child'?[['home','gift','我的心愿'],['tasks','task','我的任务'],['wallet','wallet','我的零钱']]:[['inbox','bell','待确认'],['children','parent','孩子与心愿'],['agreements','book','家庭约定']];
  const page=role==='child'?childPage:parentPage;
  return `<nav class="${isMobile?'mobile-nav':'app-nav'}" aria-label="${role==='child'?'儿童':'家长'}主导航">${items.map(([id,i,label])=>`<button class="nav-item ${page===id?'active':''}" data-nav="${id}" ${page===id?'aria-current="page"':''}>${icon(i)}<span>${label}</span></button>`).join('')}</nav>`;
}
function syncStatus(){
  const waiting=data.requests.filter(r=>!r.delivered&&!r.done).length,records=data.receipts.filter(r=>!r.received).length;
  const label=records?'有收获待接收':waiting?`${waiting} 项待发送`:pendingCount()?`${pendingCount()} 项待家长处理`:'没有待处理记录';
  return `<button class="sync-button ${records||pendingCount()?'pending':''}" data-act="sync-info" aria-label="${label}，查看互通状态">${icon(records?'download':pendingCount()?'clock':'check')}<span>${label}</span></button>`;
}
function shell(content,title,kicker){
  const p=profile();
  return `<div class="app-shell"><aside class="app-rail"><div class="brand"><span class="brand-mark">${icon('leaf')}</span><div><b>栗子小镇</b><small>PENNYWOOD</small></div></div><button class="profile-button" data-act="profiles" aria-label="切换孩子，当前${p.name}">${image('mascot','avatar')}<span><b>${p.name}</b><small>${role==='parent'?'正在管理':'心愿手账'}</small></span>${icon('chevron')}</button>${navigation()}<div class="rail-story">${image('mascot')}<p>慢慢来，也很棒。</p></div><button class="rail-parent" data-act="${role==='child'?'parent-entry':'child-entry'}">${icon(role==='child'?'lock':'back')}${role==='child'?'家长空间':'回到孩子端'}</button></aside><div class="app-main"><header class="app-header"><div><p class="kicker">${kicker}</p><h1>${title}</h1></div><div class="header-actions">${syncStatus()}<button class="mobile-profile" data-act="profiles" aria-label="切换孩子或进入家长空间，当前${p.name}">${image('mascot','avatar')}</button></div></header>${content}</div>${navigation(true)}</div>`;
}
function wishCard(side=role==='parent'?'parent':'child'){
  const w=getWish(),saved=total(side),percent=Math.min(100,100*saved/w.target),gift=w.type?w.type==='gift':w.id==='gift';
  return `<article class="wish-card"><div class="wish-copy"><div class="wish-eyebrow">${icon(gift?'gift':'coin')}头号心愿 · ${esc(w.label)}</div><h2>${esc(w.name)}</h2><div class="progress-label number"><div><strong>${whole(saved)}</strong><small> / ${whole(w.target)} 元</small></div><span>${percent.toFixed(0)}%</span></div><div class="track" role="progressbar" aria-label="已确认的心愿积累" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${percent.toFixed(0)}" aria-valuetext="已经确认${whole(saved)}元，目标${whole(w.target)}元"><i style="transform:scaleX(${percent/100})"></i></div><p>${saved>=w.target?'钱已经准备好，可以和家长商量实现啦。':`再攒 ${whole(w.target-saved)} 元，就更近一步。`}</p></div><div class="wish-art" aria-hidden="true"><span class="moon"></span><svg class="sky-spark" viewBox="0 0 150 90" fill="currentColor"><path d="m25 14 2 7 7 2-7 2-2 7-2-7-7-2 7-2Zm86 38 2 5 5 2-5 2-2 5-2-5-5-2 5-2Z"/><circle cx="64" cy="12" r="1.5"/><circle cx="12" cy="65" r="1.5"/><circle cx="130" cy="17" r="1.5"/></svg>${image(gift?'telescope':'tree-sprout')}<p>${gift?'把远方的小秘密，看近一点。':'小小的积累，也会长成大树。'}</p></div></article>`;
}
function home(){
  const next=data.wishes.find(w=>w.id!==data.wish);
  return `${wishCard()}<div class="wish-footer"><p>${next?`下个心愿 · ${esc(next.name)}`:'其他心愿可以先排队。'}</p><button data-act="wish-list">心愿夹 ${icon('chevron')}</button></div>${quickTasks()}<section class="section"><div class="section-title"><h2>还有这些小小的可能</h2><button data-nav="tasks">看看任务 ${icon('chevron')}</button></div><div class="ways">${offers.filter(o=>['labor','learn','extra'].includes(o.id)).map((o,i)=>`<button class="way" data-task="${o.id}">${icon(['home','book','spark'][i])}<b>${o.kind}</b><span>约定 ${whole(o.reward)} 元</span></button>`).join('')}</div><div class="finance-links"><button data-act="invest">让已有的零钱慢慢成长${icon('arrow')}</button><button data-act="borrow">和家长商量提前实现${icon('arrow')}</button></div></section><p class="tiny-note">主心愿显示已确认的积累。其他心愿排队，不重复分配同一笔钱。</p>`;
}
function taskPage(){
  const filtered=offers.filter(o=>taskFilter==='all'||taskFilter==='pending'&&['queued','delivered','checked','paid','revision'].includes(data.tasks[o.id])||taskFilter==='done'&&data.tasks[o.id]==='received');
  return `<div class="task-filters">${[['all','所有任务'],['pending','等待与反馈'],['done','已完成']].map(([id,label])=>`<button class="filter ${taskFilter===id?'active':''}" data-filter="${id}" aria-pressed="${taskFilter===id}">${label}</button>`).join('')}</div>${filtered.length?`<div class="task-list">${filtered.map(t=>`<button class="task-row" data-task="${t.id}">${image(t.icon||'book')}<div class="task-text"><b>${esc(t.name)}</b><p>${phaseText[data.tasks[t.id]]}</p></div><span class="reward number">${whole(t.reward)} 元</span>${icon('chevron')}</button>`).join('')}</div>`:`<div class="empty">${icon('leaf')}<h3>${taskFilter==='done'?'第一份收获，还在路上。':'暂时没有等待的任务。'}</h3><p>不用急，挑一件想做的小事就好。</p><button class="primary" data-filter="all">看看可以做什么</button></div>`}<p class="tiny-note">按事先约定完成，家长确认实际兑现后才记入零钱。</p>`;
}
function walletPage(){
  const receipts=data.receipts.filter(r=>r.received);
  return `<section class="wallet-hero"><p>我已确认的积累</p><div class="money number">${whole(total('child'))}<small> 元</small></div><p>零钱和持有本金合起来。待确认报酬与预计收益还不算。</p></section><div class="wallet-grid"><article class="account-piece"><span>可用零钱</span><strong class="number">${amount(data.child.cash)} 元</strong><p>可以为心愿安排的钱</p></article><article class="account-piece"><span>持有本金</span><strong class="number">${amount(data.child.holding)} 元</strong><p>在家庭约定中慢慢成长</p></article></div><div class="line"><span>计划待还（含未来约定利息）</span><b>0.00 元</b></div><div class="finance-links"><button data-act="invest">安排已有零钱 ${icon('arrow')}</button><button data-act="borrow">与家长商量预支 ${icon('arrow')}</button></div><section class="section"><div class="section-title"><h2>我的收获手账</h2><small>只记录确认过的收获</small></div>${receipts.length?`<ol class="timeline">${receipts.map(r=>`<li><span class="timeline-dot">${icon(r.kind==='task'?'check':'leaf')}</span><div class="timeline-text"><b>${r.kind==='task'?esc(offers.find(o=>o.id===r.taskId).name):'存入家庭教学计划'}</b><p>${r.kind==='task'?'家长已兑现 · 确认记录已收到':'零钱转为持有 · 总积累没有变'}</p></div><strong class="number">${r.kind==='task'?'+':''}${amount(r.amount)} 元</strong></li>`).join('')}</ol>`:`<div class="empty">${icon('book')}<h3>留个位置，记下每一点努力。</h3><p>第一次确认的收获会出现在这里。</p></div>`}</section>`;
}
function child(){
  const p=profile(),page={home:[home,'今天，也离心愿近一点。',`${p.name}的心愿手账`],tasks:[taskPage,'做一件自己愿意的小事。','我的任务'],wallet:[walletPage,'每一点收获，都看得见。','我的零钱']};
  const [renderPage,title,kicker]=page[childPage];return shell(renderPage(),title,kicker);
}
function childSwitcher(){return `<div class="child-switcher" aria-label="选择管理的孩子">${profiles.map(p=>{const d=family[p.id],count=d.requests.filter(r=>r.delivered&&!r.done).length;return `<button class="child-chip ${p.id===activeChild?'selected':''}" data-child="${p.id}" aria-pressed="${p.id===activeChild}">${image('mascot','avatar')}<span><b>${p.name}</b><small>${count?`${count} 项待处理`:'暂无待处理'}</small></span>${p.id===activeChild?icon('check'):icon('chevron')}</button>`;}).join('')}</div>`;}
function parentInbox(){
  const inbox=data.requests.filter(r=>r.delivered&&!r.done),w=getWish();
  return `${childSwitcher()}<div class="parent-summary"><div><p>${profile().name} · 已确认积累</p><strong class="number">${whole(total('parent'))} 元</strong><p>孩子端显示 ${whole(total('child'))} 元</p></div><div class="small-progress"><b>${esc(w.name)}</b><div class="track"><i style="transform:scaleX(${Math.min(1,total('parent')/w.target)})"></i></div><small>目标 ${whole(w.target)} 元</small></div></div><div class="section-title"><h2>待处理 ${inbox.length} 项</h2><small>检查与兑现分开记录</small></div><div class="parent-inbox">${inbox.length?inbox.map(r=>{const t=offers.find(o=>o.id===r.taskId);return `<article class="parent-card"><div class="parent-task-title">${image(t?.icon||'book')}<h3>${r.kind==='task'?esc(t.name):r.kind==='invest'?'申请存入 10 元':'想商量预支'}</h3>${r.kind==='task'?`<span class="reward number">${whole(t.reward)} 元</span>`:''}</div><p>${r.kind==='task'?phaseText[data.tasks[r.taskId]]+' · '+profile().name+'提交':r.kind==='invest'?'90 天 · 年化 3% · 预计利息 0.07 元':'先谈清条件，再由孩子接受。不会自动形成欠款。'}</p><button class="mini-button" data-request="${r.id}">${r.kind==='task'?(data.tasks[r.taskId]==='checked'?'确认实际兑现':'查看并检查'):r.kind==='invest'?'查看本金转移':'查看提议'} ${icon('chevron')}</button></article>`;}).join(''):`<div class="empty">${icon('check')}<h3>这一刻，没有需要处理的事。</h3><p>收到${profile().name}的提交后，会在这里告诉您。</p></div>`}</div><p class="tiny-note">只显示已送达的请求；孩子提交、检查通过均不增加金额。</p>`;
}
function parentChildren(){return `${childSwitcher()}<p class="scope-note">正在查看 ${profile().name}。心愿、任务和零钱独立记录。</p>${wishCard()}<div class="button-row"><button class="secondary" data-act="wish-list">查看心愿夹</button><button class="secondary" data-act="wallet">查看孩子的零钱</button></div><section class="section"><div class="section-title"><h2>一起坚持的方式</h2></div><article class="agreement-card"><h3>认真看见每一次行动</h3><p>可以问问孩子发现了什么、遇到了什么困难。完成记录不需要连续签到，也不会因中断而清零。</p></article></section>`;}
function agreements(){return `<p class="scope-note">当前为${profile().name}的家庭约定示例，正式使用由家长与孩子事先商量。</p><article class="agreement-card"><h3>常做任务 · 做好了就提交</h3><p>洗碗 2 元、拖地 3 元、整理玩具 2 元、摘菜 1 元。约定包括范围、标准和报酬。</p><button class="text-btn" data-act="task-agreements">查看各项完成标准</button></article><article class="agreement-card"><h3>主动学习 · 重视探索和发现</h3><p>自主阅读 20 分钟，分享一个感兴趣的发现，约定 5 元。不是打开学习页或达到分数就发钱。</p><button class="text-btn" data-task="learn">查看学习约定</button></article><article class="agreement-card"><h3>家庭教学理财 · 收益由家长承担</h3><p>每份约定分别保存本金、期限、利率和分红方式。预计收益单列，不能作为现在的钱。</p><button class="text-btn" data-act="invest">查看一份示例条件</button></article><article class="agreement-card"><h3>预支 · 先谈条件，再实际垫付</h3><p>孩子接受最终条件后，家长实际垫付才生效。计划待还始终单独显示。</p><button class="text-btn" data-act="borrow">查看预支成本示例</button></article>`;}
function parent(){const page={inbox:[parentInbox,'先看见努力，再确认收获。','家长空间 · 待确认'],children:[parentChildren,'小小的目标，一起认真对待。','家长空间 · 孩子与心愿'],agreements:[agreements,'把约定说清楚，把承诺记下来。','家长空间 · 家庭约定']};const [fn,title,kicker]=page[parentPage];return shell(fn(),title,kicker);}
function render(){
  const previousScroll=document.querySelector('.app-main')?.scrollTop||0;
  document.getElementById('device').className='device'+(mode==='tablet'?' tablet':'');
  document.getElementById('screen').innerHTML=role==='child'?child():parent();
  document.querySelector('.app-main').scrollTop=previousScroll;
  for(const [id,on] of [['phone-mode',mode==='phone'],['tablet-mode',mode==='tablet'],['child-role',role==='child'],['parent-role',role==='parent']]){const b=document.getElementById(id);b.classList.toggle('on',on);b.setAttribute('aria-pressed',on);}
  const waiting=data.requests.filter(r=>!r.delivered&&!r.done).length,records=data.receipts.filter(r=>!r.received).length;
  document.getElementById('simulation-child').textContent=profile().name;
  document.getElementById('queue-count').textContent=`${waiting} 项待发送 · ${records} 笔待接收`;
  document.getElementById('queue-note').textContent='只模拟当前孩子的消息。送达后切到家长端检查与兑现。';
  document.getElementById('deliver-button').disabled=!waiting;
  document.getElementById('receive-button').disabled=!records;
  document.getElementById('sync-facts').innerHTML=`<span>孩子端已确认<b>${amount(total('child'))} 元</b></span><span>家长端已确认<b>${amount(total('parent'))} 元</b></span>`;
  document.getElementById('event-list').innerHTML=data.events.map(e=>`<li>${esc(e)}</li>`).join('');
  renderModal();
}
function open(name,taskId){
  if(!modal){const b=document.activeElement;returnFocus=b?.dataset.quick?`[data-quick="${b.dataset.quick}"]`:b?.dataset.act?`[data-act="${b.dataset.act}"]`:null;}
  if(taskId)selectedTask=taskId;
  modal=name;errors={};renderModal();
  requestAnimationFrame(()=>document.querySelector('.sheet .close')?.focus());
}
function closeModal(){modal=null;renderModal();if(returnFocus)document.querySelector(returnFocus)?.focus({preventScroll:true});}
function steps(phase){const labels=['已提交，等待发送','家长检查','家长实际兑现','收到记录，计入零钱'],pos=({queued:0,delivered:1,checked:2,paid:3,received:4})[phase]??0;return `<ol class="status-steps">${labels.map((s,i)=>`<li class="${i<pos?'done-step':i===pos?'current-step':''}"><span class="step-number">${i<pos?icon('check'):i+1}</span>${s}</li>`).join('')}</ol>`;}
function taskModal(){
  const t=offers.find(o=>o.id===selectedTask),phase=data.tasks[selectedTask];
  let body=`<span class="tag">${t.kind} · 约定 ${whole(t.reward)} 元</span><p>${phaseText[phase]}</p>`;
  if(phase==='revision')body+=`<div class="notice"><b>家长的小提醒</b><br>${esc(data.notes[t.id])}</div>`;
  body+=`<div class="requirements"><b>现实中这样做</b><ol>${t.steps.map(s=>`<li>${esc(s)}</li>`).join('')}</ol></div>`;
  if(['queued','delivered','checked','paid','received'].includes(phase))body+=steps(phase);
  if(role==='child'){
    if(phase==='available')body+='<button class="primary" data-act="accept">我来试试</button>';
    if(['accepted','revision'].includes(phase))body+=`<button class="primary" data-act="submit">${phase==='revision'?'我改好了，重新提交':'做好了，提交给家长'}</button>`;
    if(t.quick&&['queued','delivered'].includes(phase))body+=`<button class="mini-button withdraw" data-withdraw="${t.id}">点错了，撤回本次提交</button>`;
  }
  if(phase==='received')body+=`<div class="requirements"><b>这次的收获 +${whole(t.reward)} 元</b>家长已兑现，确认记录已收到。每一点努力，都被看见。</div>`;
  body+='<p class="notice">提交和检查不会增加零钱。家长实际兑现、孩子设备收到记录后，才显示这笔收获。</p>';
  return {title:t.name,body};
}
function requestModal(r){
  if(!r||role!=='parent')return {title:'此项不能在这里处理',body:'<p>请返回家长空间查看。</p>'};
  if(r.kind==='task'){
    const t=offers.find(o=>o.id===r.taskId),phase=data.tasks[r.taskId];
    return {title:phase==='checked'?'确认实际兑现':'看见孩子的努力',body:`<span class="tag">正在处理 · ${profile().name}</span><p>${esc(t.name)} · 约定报酬 ${whole(t.reward)} 元</p><div class="requirements"><b>一起约好的标准</b><ol>${t.steps.map(s=>`<li>${esc(s)}</li>`).join('')}</ol></div>${phase==='delivered'?`<button class="primary" data-check="${r.id}">检查通过 · 暂不入账</button><button class="text-btn full" data-revise="${r.id}">还差一点，告诉孩子怎么改</button>`:phase==='checked'?`<label class="check"><input type="checkbox" id="fulfilled" ${fulfilledRequests.has(r.id)?'checked':''}><span>我已经实际交付报酬，或在家庭中预留代管 ${whole(t.reward)} 元，确认记入${profile().name}名下。</span></label><button class="primary warm" data-pay="${r.id}" id="pay-button" ${fulfilledRequests.has(r.id)?'':'disabled'}>确认兑现 ${whole(t.reward)} 元</button>`:'<p class="notice">此项已经处理。</p>'}<p class="notice">检查与实际兑现分两步。兑现后，孩子端收到记录才更新进度。</p>`};
  }
  if(r.kind==='invest')return {title:'确认这次存入',body:`<span class="tag">正在处理 · ${profile().name}</span><p>已约定本金 10 元，期限 90 天，年化 3%，到期预计利息 0.07 元。</p><div class="requirements">零钱 ${amount(data.parent.cash)} → ${amount(data.parent.cash-1000)} 元<br>持有本金 ${amount(data.parent.holding)} → ${amount(data.parent.holding+1000)} 元<br>总积累仍为 ${amount(total('parent'))} 元</div><p class="notice">只转移已有本金，预计利息暂不计入心愿。本原型不推进日期或结算收益。</p><button class="primary" data-invest-confirm="${r.id}" ${data.parent.cash<1000?'disabled':''}>确认存入 · 只转移本金</button>`};
  return {title:'收到孩子的预支想法',body:'<p>先一起谈清最终金额、期限、利息和还款安排。孩子接受后，家长实际垫付才生效。</p><p class="notice">本轮仅演示提议，没有实际垫付、购入或新增欠款。</p><button class="primary" data-act="close">知道了，稍后一起商量</button>'};
}
function investModal(){return {title:'让已有的零钱慢慢成长',body:`<p>把已经有的零钱留一段时间，体验积累。收益由家长按事先约定与预算承担。</p><div class="requirements"><b>一份家庭教学约定</b>本金 10 元 · 90 天 · 年化 3%<br>到期预计利息 0.07 元<br>提前取回按约定重算收益</div><p class="notice">存入只是零钱变成持有，本金没有变多。预计利息现在不算心愿进度。</p>${role==='child'?`<button class="primary" data-act="invest-request" ${data.child.cash<1000?'disabled':''}>按这份约定申请存入 10 元</button>${data.child.cash<1000?'<p class="field-error">当前零钱不足 10 元，可以先慢慢积累。</p>':''}`:'<button class="primary" data-act="close">了解这份示例约定</button>'}`};}
function borrowModal(){
  const w=getWish(),gift=w.type?w.type==='gift':w.id==='gift';
  if(!gift)return {title:'攒钱目标，靠自己慢慢积累',body:'<p>借来的钱不能算作自己攒到的钱，也不能用来填满“攒到 200 元”的目标。</p><div class="requirements">可以继续行动，积累已兑现的报酬与已结算的收益，或与家长调整安排。</div><button class="primary" data-act="close">回去慢慢积累</button>'};
  const gap=Math.max(0,w.target-total('child')),p1=Math.floor(gap/3),p2=p1,p3=gap-p1-p2,i1=Math.round(gap*.06/12),i2=Math.round((gap-p1)*.06/12),i3=Math.round(p3*.06/12);
  return {title:'想提前实现？先一起算一算。',body:`<p>礼物可以讨论提前得到，但要承担后续还款。先看清条件，再决定。</p><div class="requirements"><b>用于理解的示例提议</b>目标 ${whole(w.target)} 元 · 已有积累 ${whole(total('child'))} 元<br>暂缺 ${amount(gap)} 元<br>若垫付 ${amount(gap)} 元，3 个月、年利率 6%：<br>三期分别 ${amount(p1+i1)}、${amount(p2+i2)}、${amount(p3+i3)} 元<br><b>计划共还 ${amount(gap+i1+i2+i3)} 元</b></div><p class="notice">家长另提最终条件。预支不进入零钱，不提高“自己攒到”的进度；自付部分也需要实际交付。</p>${role==='child'&&gap>0?'<button class="primary" data-act="borrow-request">先把想法告诉家长</button>':'<button class="primary" data-act="close">知道了</button>'}`};
}
function wishForm(){return {title:'放进一个小心愿',body:`<p>想要一份礼物，或攒到一个数目，都可以。</p><form id="wish-form" novalidate>${Object.keys(errors).length?'<div class="form-summary" role="alert" tabindex="-1">还有一点需要补充，请检查下面的提示。</div>':''}<label class="field" for="wish-type">心愿类型<select id="wish-type" name="type"><option value="gift" ${wishDraft.type==='gift'?'selected':''}>一份想要的礼物</option><option value="save" ${wishDraft.type==='save'?'selected':''}>一个攒钱目标</option></select></label><label class="field" for="wish-name">我想要什么<input id="wish-name" name="name" value="${esc(wishDraft.name)}" maxlength="30" autocomplete="off" aria-invalid="${!!errors.name}" aria-describedby="name-hint${errors.name?' name-error':''}"><span id="name-hint" class="field-hint">例如：一辆滑板车；最多 30 个字。</span>${errors.name?`<span class="field-error" id="name-error">${errors.name}</span>`:''}</label><label class="field" for="wish-target">目标金额（元）<input id="wish-target" name="target" value="${esc(wishDraft.target)}" inputmode="decimal" autocomplete="off" aria-invalid="${!!errors.target}" aria-describedby="target-hint${errors.target?' target-error':''}"><span id="target-hint" class="field-hint">先估一个价格，之后和家长一起商量。</span>${errors.target?`<span class="field-error" id="target-error">${errors.target}</span>`:''}</label><p class="notice">新心愿先放进心愿夹排队，不会多出一份零钱。</p><button class="primary" type="submit">放进心愿夹</button></form>`};}
function renderModal(){
  const root=document.getElementById('modal-root');document.getElementById('screen').inert=!!modal;
  if(!modal){root.innerHTML='';return;}
  let view={title:'',body:''};
  if(modal==='task')view=taskModal();
  else if(modal.startsWith('request:'))view=requestModal(data.requests.find(r=>r.id===modal.slice(8)));
  else if(modal==='invest')view=investModal();
  else if(modal==='borrow')view=borrowModal();
  else if(modal==='wallet')view={title:`${profile().name}的零钱`,body:`<div class="line"><span>可用零钱</span><b>${amount(data.child.cash)} 元</b></div><div class="line"><span>持有本金</span><b>${amount(data.child.holding)} 元</b></div><div class="line"><span>计划待还（含未来利息）</span><b>0.00 元</b></div><p class="notice">未兑现报酬、预计收益与预支提议都不计入。此原型尚未创建实际借款。</p>`};
  else if(modal==='sync-info')view={title:'每一步，都有清楚的状态',body:`<p>没有网时也可以提交，连上后再尝试发送。在家长处理之前，零钱不会提前增加。</p><div class="requirements">待发送 → 待家长检查 → 待兑现 → 待接收记录 → 已记入零钱</div><p class="notice">本页是设计原型，未连接 iCloud。顶部“互通演示”里的按钮可模拟送达与接收；正式版自动尝试同步。</p>`};
  else if(modal==='profiles')view={title:role==='child'?'今天是谁的小心愿？':'选择要查看的孩子',body:`<p>每个人的心愿、任务和零钱都分别记好。</p><div style="margin-top:20px">${childSwitcher()}</div>${role==='child'?'<button class="secondary full" data-act="parent-entry">家长空间 · 预览入口</button>':''}<p class="notice">示例家庭可直接切换。正式版进入家长空间需要家长锁与设备授权。</p>`};
  else if(modal==='parent-entry')view={title:'家长空间',body:'<p>这里由家长检查任务、确认实际兑现，并商量家庭约定。</p><p class="notice">这份原型没有连接正式身份验证。以下仅为设计预览，正式 APP 使用家长锁。</p><button class="primary" data-act="parent-preview">进入家长预览</button>'};
  else if(modal==='wish-list')view={title:'心愿夹，装下小小的期待',body:`<p>一次专心实现一个。排队的心愿不重复计算零钱。</p>${data.wishes.map(w=>`<article class="wish-list-card"><h3>${esc(w.name)}</h3><p>${esc(w.label)} · 目标 ${whole(w.target)} 元 · ${w.id===data.wish?'头号心愿':'排队中'}</p>${w.id!==data.wish?`<button class="mini-button" data-wish="${w.id}" ${data.wishes.length===2?'data-act="switch-wish"':''}>设为主心愿</button>`:''}</article>`).join('')}<button class="primary" data-act="new-wish">${icon('plus')}放进一个新心愿</button>`};
  else if(modal==='new-wish')view=wishForm();
  else if(modal==='task-agreements')view={title:'已经约好的常做任务',body:offers.filter(t=>t.quick).map(t=>`<article class="wish-list-card"><h3>${esc(t.quickName)} · ${whole(t.reward)} 元</h3><p>${t.steps.map(esc).join('；')}</p></article>`).join('')};
  else if(modal.startsWith('revise:'))view={title:'给孩子一个具体的小提醒',body:`<p>说说哪里需要再试试，孩子改好后可以重新提交。</p><form id="revision-form" novalidate><label class="field" for="revision-note">还有哪里要改<textarea id="revision-note" maxlength="100" aria-describedby="revision-error">${esc(revisionDraft)}</textarea><span class="field-error" id="revision-error">${errors.note||''}</span></label><button class="primary" type="submit">告诉${profile().name}，这次先不入账</button></form>`};
  root.innerHTML=`<div class="overlay"><section class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title"><header class="sheet-head"><h2 id="sheet-title">${esc(view.title)}</h2><button class="close" data-act="close" aria-label="关闭面板">${icon('close')}</button></header>${view.body}</section></div>`;
}
function switchChild(id){if(!family[id])return;activeChild=id;data=family[id];modal=null;clearToast();render();document.querySelector('.app-main').scrollTop=0;}
function setRole(next){role=next;modal=null;clearToast();render();document.querySelector('.app-main').scrollTop=0;}
function deliver(){for(const r of data.requests.filter(r=>!r.delivered&&!r.done)){r.delivered=true;if(r.kind==='task')data.tasks[r.taskId]='delivered';}addEvent('演示网络：请求已送达家长。');render();}
function receive(){
  let earned=0;
  for(const r of data.receipts.filter(r=>!r.received)){if(r.kind==='task'){data.child.cash+=r.amount;earned+=r.amount;data.tasks[r.taskId]='received';}else{data.child.cash-=r.amount;data.child.holding+=r.amount;}r.received=true;}
  addEvent('演示网络：确认记录已接收，重复接收不会重复入账。');render();
  toast(earned?`这次确认的收获 ${whole(earned)} 元，离心愿又近了一点。`:'记录已收到。本金换了位置，总积累没有变化。');
}
document.addEventListener('click',e=>{
  const b=e.target.closest('button');if(!b||b.disabled)return;
  if(b.dataset.role){setRole(b.dataset.role);return;}
  if(b.dataset.device){mode=b.dataset.device;const u=new URL(location.href);u.searchParams.set('device',mode);history.replaceState(null,'',u);render();return;}
  if(b.dataset.child){switchChild(b.dataset.child);return;}
  if(b.dataset.nav){if(role==='child')childPage=b.dataset.nav;else parentPage=b.dataset.nav;modal=null;clearToast();render();document.querySelector('.app-main').scrollTop=0;return;}
  if(b.dataset.filter){taskFilter=b.dataset.filter;render();return;}
  if(b.dataset.quick){quickSubmit(b.dataset.quick);return;}
  if(b.dataset.withdraw){withdrawSubmission(b.dataset.withdraw);return;}
  if(b.dataset.task){open('task',b.dataset.task);return;}
  if(b.dataset.request){open('request:'+b.dataset.request);return;}
  if(b.dataset.wish){data.wish=b.dataset.wish;modal=null;render();toast('头号心愿换好了，零钱还是原来的一份。');return;}
  if(b.dataset.revise&&role==='parent'){revisionDraft='';open('revise:'+b.dataset.revise);return;}
  if(b.dataset.check&&role==='parent'){
    const r=data.requests.find(r=>r.id===b.dataset.check);if(!r||r.done||data.tasks[r.taskId]!=='delivered')return;
    data.tasks[r.taskId]='checked';addEvent('家长检查通过，金额不变。');render();document.querySelector('.sheet .close')?.focus();return;
  }
  if(b.dataset.pay&&role==='parent'){
    const r=data.requests.find(r=>r.id===b.dataset.pay);if(!r||r.done||data.tasks[r.taskId]!=='checked'||!document.getElementById('fulfilled')?.checked)return;
    const t=offers.find(t=>t.id===r.taskId);data.parent.cash+=t.reward;r.done=true;data.tasks[t.id]='paid';
    data.receipts.push({id:r.id,kind:'task',taskId:t.id,received:false,amount:t.reward});
    addEvent(`家长确认实际兑现 +${amount(t.reward)} 元，待孩子接收。`);modal=null;render();toast('兑现记录已记好，孩子接收后会看到收获。');return;
  }
  if(b.dataset.investConfirm&&role==='parent'){
    const r=data.requests.find(r=>r.id===b.dataset.investConfirm);if(!r||r.done||data.parent.cash<1000)return;
    data.parent.cash-=1000;data.parent.holding+=1000;r.done=true;data.receipts.push({id:r.id,kind:'invest',received:false,amount:1000});
    addEvent('家长确认存入10元，总积累不变，等待孩子接收。');modal=null;render();return;
  }
  switch(b.dataset.act){
    case 'close':closeModal();break;
    case 'accept':if(role!=='child'||data.tasks[selectedTask]!=='available')return;data.tasks[selectedTask]='accepted';addEvent('孩子接下任务，未入账。');modal=null;render();toast('现在去现实中行动，做完再回来。');break;
    case 'submit':if(role!=='child'||!['accepted','revision'].includes(data.tasks[selectedTask]))return;data.tasks[selectedTask]='queued';request('task',selectedTask);modal=null;render();toast('已提交，等待送达家长。零钱还没有变化。');break;
    case 'deliver':deliver();break;
    case 'receive':receive();break;
    case 'switch-wish':data.wish=data.wishes.find(w=>w.id!==data.wish).id;modal=null;render();break;
    case 'invest':open('invest');break;
    case 'invest-request':if(role!=='child'||data.child.cash<1000)return;request('invest');modal=null;render();toast('存入申请已提交，零钱暂不改变。');break;
    case 'borrow':open('borrow');break;
    case 'borrow-request':if(role!=='child')return;request('borrow');modal=null;render();toast('想法已提交，还没有产生借款。');break;
    case 'wallet':open('wallet');break;
    case 'sync-info':open('sync-info');break;
    case 'profiles':open('profiles');break;
    case 'wish-list':open('wish-list');break;
    case 'new-wish':wishDraft={name:'',target:'',type:'gift'};open('new-wish');break;
    case 'task-agreements':open('task-agreements');break;
    case 'parent-entry':open('parent-entry');break;
    case 'parent-preview':setRole('parent');break;
    case 'child-entry':setRole('child');break;
  }
});
document.addEventListener('change',e=>{if(e.target.id==='fulfilled'){document.getElementById('pay-button').disabled=!e.target.checked;const id=modal.slice(8);if(e.target.checked)fulfilledRequests.add(id);else fulfilledRequests.delete(id);}if(e.target.id==='wish-type')wishDraft.type=e.target.value;});
document.addEventListener('input',e=>{if(e.target.id==='wish-name')wishDraft.name=e.target.value;if(e.target.id==='wish-target')wishDraft.target=e.target.value;if(e.target.id==='revision-note')revisionDraft=e.target.value;});
document.addEventListener('submit',e=>{
  if(e.target.id==='wish-form'){
    e.preventDefault();errors={};
    if(!wishDraft.name.trim())errors.name='给这个心愿起个名字吧。';
    if(!/^\d{1,6}(\.\d{1,2})?$/.test(wishDraft.target.trim()))errors.target='请输入金额，最多保留两位小数。';
    const [yuan,cent='']=wishDraft.target.trim().split('.'),target=Number(yuan)*100+Number(cent.padEnd(2,'0'));
    if(!errors.target&&target<=0)errors.target='目标金额需要大于 0 元。';
    if(Object.keys(errors).length){renderModal();document.querySelector('.form-summary')?.focus();return;}
    data.wishes.push({id:`custom-${++data.seq}`,type:wishDraft.type,name:wishDraft.name.trim(),target,label:wishDraft.type==='gift'?'礼物心愿':'攒钱目标'});
    modal='wish-list';render();toast('新心愿放好啦，等你准备好再设为头号心愿。');
  }
  if(e.target.id==='revision-form'){
    e.preventDefault();if(role!=='parent')return;errors={};
    if(!revisionDraft.trim()){errors.note='请写下一个具体的小提醒。';renderModal();document.getElementById('revision-note').focus();return;}
    const r=data.requests.find(r=>r.id===modal.slice(7));if(!r||r.done||data.tasks[r.taskId]!=='delivered')return;
    data.tasks[r.taskId]='revision';data.notes[r.taskId]=revisionDraft.trim();r.done=true;addEvent('家长给出具体提醒，未入账。');modal=null;render();toast('提醒已记好，孩子改好后可以重新提交。');
  }
});
document.addEventListener('keydown',e=>{
  if(!modal)return;
  if(e.key==='Escape'){closeModal();return;}
  if(e.key==='Tab'){
    const nodes=[...document.querySelectorAll('.sheet button:not(:disabled),.sheet input,.sheet select,.sheet textarea,.sheet [tabindex="0"]')].filter(n=>n.getClientRects().length);
    const first=nodes[0],last=nodes.at(-1);if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}
  }
});
document.getElementById('reset').onclick=()=>{family=Object.fromEntries(profiles.map(p=>[p.id,initial(p.cash)]));activeChild='li';data=family.li;role='child';childPage='home';parentPage='inbox';modal=null;selectedTask='labor';fulfilledRequests.clear();clearToast();render();};
document.getElementById('present').onclick=()=>{const u=new URL(location.href);u.searchParams.set('present','1');location.href=u;};
document.getElementById('theme').onclick=()=>{const dark=document.body.dataset.theme!=='dark';document.body.dataset.theme=dark?'dark':'light';document.getElementById('theme').textContent=dark?'浅色':'深色';};
document.getElementById('text-size').onclick=e=>{const large=document.body.classList.toggle('large-text');e.currentTarget.setAttribute('aria-pressed',large);};
document.getElementById('simulation-toggle').onclick=e=>{const open=document.querySelector('.lab-layout').classList.toggle('simulation-open');e.currentTarget.setAttribute('aria-expanded',open);if(open&&innerWidth<1200)document.getElementById('simulation-panel').scrollIntoView({behavior:'instant',block:'start'});};
if(params.get('present')==='1')document.body.classList.add('present');
if(params.get('role')==='parent')role='parent';
if(params.get('theme')==='dark'||!params.has('theme')&&matchMedia('(prefers-color-scheme:dark)').matches){document.body.dataset.theme='dark';document.getElementById('theme').textContent='浅色';}
render();
