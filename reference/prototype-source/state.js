/* Prototype state is memory-only. Amounts are cents; example rates are not market quotes. */
const Products = {
  sprout: {key:'sprout', name:'小树定期', subtitle:'给一个小目标，留一点时间', days:90, minimum:1000, tag:'90 天计划', type:'fixed'},
  annual: {key:'annual', name:'年轮定期', subtitle:'把今天的努力，留给明年的自己', days:365, minimum:5000, tag:'一年慢慢长', type:'fixed'},
  dividend: {key:'dividend', name:'小镇分红计划', subtitle:'收益拿出来，还是留下来继续长？', days:30, minimum:1000, tag:'30 天一期 · 家庭教学计划', type:'income'},
  money: {key:'money', name:'零钱基金', subtitle:'认识收益变化与收益结转', tag:'产品课堂', type:'preview'},
  index: {key:'index', name:'森林指数', subtitle:'认识净值涨跌与长期持有', tag:'产品课堂', type:'preview'},
};
const Money = {
  format(cents){return (cents/100).toLocaleString('zh-CN',{minimumFractionDigits:2,maximumFractionDigits:2});},
  parse(value){const text=String(value).trim();if(!/^\d+(\.\d{1,2})?$/.test(text))return null;const [whole,part='']=text.split('.');const n=Number(whole)*100+Number(part.padEnd(2,'0'));return Number.isSafeInteger(n)?n:null;},
  interest(cents,bps,days){const numerator=BigInt(cents)*BigInt(bps)*BigInt(days);const denominator=3650000n;return Number((numerator+denominator/2n)/denominator);},
  monthInterest(cents,bps){return Number((BigInt(cents)*BigInt(bps)+60000n)/120000n);},
};
const Day = {
  add(value,count){const date=new Date(`${value}T00:00:00Z`);date.setUTCDate(date.getUTCDate()+count);return date.toISOString().slice(0,10);},
  difference(a,b){return Math.round((Date.parse(`${b}T00:00:00Z`)-Date.parse(`${a}T00:00:00Z`))/86400000);},
  label(value){const [y,m,d]=value.split('-');return `${Number(m)}月${Number(d)}日`;},
  month(value,count){const [y,m,d]=value.split('-').map(Number);const date=new Date(Date.UTC(y,m-1+count,1));const last=new Date(Date.UTC(date.getUTCFullYear(),date.getUTCMonth()+1,0)).getUTCDate();date.setUTCDate(Math.min(d,last));return date.toISOString().slice(0,10);},
  valid(value){return /^\d{4}-\d{2}-\d{2}$/.test(value)&&!Number.isNaN(Date.parse(value+'T00:00:00Z'))&&new Date(value+'T00:00:00Z').toISOString().slice(0,10)===value;},
};
const Engine = {
  initial(){return {
    now:'2026-10-31',profileId:'xiaoman',pin:'1111',child:'小满',wallet:4800,laborTotal:14800,bonusEarned:0,withdrawn:0,repaidTotal:0,loans:[],distribution:'cash',budget:2000,rateBps:300,sequence:20,goal:19800,weeklyPlan:2000,
    positions:[{id:'position-1',product:'annual',principal:10000,rateBps:300,days:365,start:'2026-01-15',end:'2027-01-15',expected:300,status:'active'}],
    tasks:[
      {id:'books',name:'给书架来次大整理',detail:'分类摆好图书，和家长一起检查',amount:800,duration:'约 15 分钟',status:'available',art:'book'},
      {id:'plant',name:'照顾阳台的小花园',detail:'浇水、整理枯叶，记得节约用水',amount:500,duration:'约 10 分钟',status:'available',art:'plant'},
      {id:'breakfast',name:'当一次早餐小帮手',detail:'和家长一起准备，避开热锅与刀具',amount:1200,duration:'约 20 分钟',status:'available',art:'breakfast'},
      {id:'recycle',name:'把可回收物分好类',detail:'纸箱和塑料瓶各归各位',amount:600,duration:'约 10 分钟',status:'accepted',art:'recycle'},
    ],
    requests:[],
    history:[
      {id:'history-1',date:'2026-10-25',title:'上周的劳动报酬',detail:'家长已确认并代为保管',amount:1800,type:'income'},
      {id:'history-2',date:'2026-10-18',title:'认真照顾小花园',detail:'劳动报酬已记入零钱钱包',amount:1000,type:'income'},
      {id:'history-3',date:'2026-01-15',title:'给未来存一笔努力',detail:'100.00 元存入年轮定期',amount:10000,type:'invest'},
    ],
  };},
  active(s){return s.positions.filter(p=>p.status==='active');},
  reserved(s){return this.active(s).reduce((total,p)=>total+p.expected,0);},
  budgetFree(s){return s.budget-s.bonusEarned-this.reserved(s);},
  holding(s){return this.active(s).reduce((total,p)=>total+p.principal,0);},
  pendingCash(s){return s.requests.filter(r=>r.status==='pending').reduce((total,r)=>total+r.amount,0);},
  assets(s){return s.wallet+this.holding(s)+this.pendingCash(s);},
  debt(s){return s.loans.filter(l=>l.status==='active').reduce((total,l)=>total+this.loanBalance(l),0);},
  net(s){return this.assets(s)-this.debt(s);},
  log(s,title,detail,amount,type,date=s.now){s.history.unshift({id:`history-${++s.sequence}`,date,title,detail,amount,type});},
  buy(s,key,amount,distribution=s.distribution){
    const product=Products[key];
    if(!product||!['fixed','income'].includes(product.type))return {ok:false,message:'这类产品还在课堂里，先了解它的规则吧。'};
    if(!['cash','reinvest'].includes(distribution))return {ok:false,message:'请选择现金分红或红利再投。'};
    if(!Number.isSafeInteger(amount)||amount<product.minimum)return {ok:false,message:`这份计划从 ${Money.format(product.minimum)} 元开始，先慢慢攒起来。`};
    if(amount>s.wallet)return {ok:false,message:`零钱钱包里现在有 ${Money.format(s.wallet)} 元，先调整一下金额吧。`};
    const expected=Money.interest(amount,s.rateBps,product.days);
    if(expected>this.budgetFree(s))return {ok:false,message:'家长还没有预留足够的本期收益预算。这次先留在钱包，已有约定不受影响。'};
    const position={id:`position-${++s.sequence}`,product:key,principal:amount,rateBps:s.rateBps,days:product.days,start:s.now,end:Day.add(s.now,product.days),expected,status:'active',distribution};
    s.wallet-=amount;s.positions.unshift(position);
    this.log(s,`存入${product.name}`,`本期预计收益 ${Money.format(expected)} 元，家长已按约预留`,amount,'invest');
    return {ok:true,position,message:'已经存好啦，给这份努力一点时间。'};
  },
  task(s,id,action){
    const task=s.tasks.find(t=>t.id===id);
    const transitions={accept:['available','accepted'],submit:['accepted','submitted'],approve:['submitted','confirmed'],pay:['confirmed','paid']};
    const step=transitions[action];
    if(!task||!step||task.status!==step[0])return {ok:false,message:'这项任务已经更新了，看看最新进度吧。'};
    task.status=step[1];
    if(action==='pay'){s.wallet+=task.amount;s.laborTotal+=task.amount;this.log(s,task.name,'劳动报酬已兑现，由家长代为保管',task.amount,'income');}
    return {ok:true,task,message:{accept:'任务接好啦！在现实中完成，再回来告诉家长。',submit:'已告诉家长，等待检查与确认。',approve:'已确认完成，报酬现在等待兑现。',pay:`已记入 ${Money.format(task.amount)} 元劳动报酬。`}[action]};
  },
  addTask(s,name,amount){
    if(!name.trim()||name.trim().length>30)return {ok:false,message:'请填写 1–30 个字的任务名称。'};
    if(!Number.isSafeInteger(amount)||amount<100||amount>20000)return {ok:false,message:'示例任务报酬请填写 1–200 元。'};
    s.tasks.unshift({id:`task-${++s.sequence}`,name:name.trim(),detail:'完成标准由家长与孩子事前商量',amount,duration:'亲子约定',status:'available',art:'book'});
    return {ok:true,message:'新委托已放进孩子的任务板。'};
  },
  advance(s,days){
    s.now=Day.add(s.now,days);const matured=[];
    let due;
    while((due=this.active(s).filter(p=>p.end<=s.now).sort((a,b)=>a.end.localeCompare(b.end))[0])){
      const p=due;p.status='matured';s.wallet+=p.principal+p.expected;s.bonusEarned+=p.expected;matured.push(p);
      if(Products[p.product].type==='income'){
        this.log(s,'小镇计划按约分配收益',p.distribution==='reinvest'?'选择红利再投，检查同条件续期预算':'选择现金分红，收益进入零钱钱包',p.expected,'yield',p.end);
        if(p.rateBps===s.rateBps){
          const today=s.now;s.now=p.end;const result=this.buy(s,p.product,p.distribution==='reinvest'?p.principal+p.expected:p.principal,p.distribution);s.now=today;
          if(result.ok){p.renewalId=result.position.id;p.renewalPrincipal=result.position.principal;}
          else p.renewalMessage='下一期预算不足，本金和收益都留在钱包。';
        }else p.renewalMessage='家庭已提出新利率，本金和收益留在钱包，重新确认后再投入。';
      }else this.log(s,`${Products[p.product].name}到期了`,`本金 ${Money.format(p.principal)} 元已回到钱包；家长按约结算收益`,p.expected,'yield',p.end);
    }
    return {ok:true,matured,message:matured.length?'你的计划到期啦，本金和收益已经回到钱包。':'演示日期已更新，已有约定继续生效。'};
  },
  nextMaturity(s){const ends=this.active(s).map(p=>p.end).sort();return ends.length?Math.max(0,Day.difference(s.now,ends[0])):null;},
  redeem(s,id){
    const p=s.positions.find(p=>p.id===id&&p.status==='active');
    if(!p)return {ok:false,message:'这份计划已经结算过了。'};
    const elapsed=Math.max(0,Math.min(p.days,Day.difference(p.start,s.now)));const profit=Money.interest(p.principal,Math.min(10,p.rateBps),elapsed);
    p.status='redeemed';s.wallet+=p.principal+profit;s.bonusEarned+=profit;
    this.log(s,`提前取回${Products[p.product].name}`,`按事前约定的活期示例利率 0.10% 重算收益，本金完整取回`,profit,'yield');
    return {ok:true,message:`本金与 ${Money.format(profit)} 元已结算收益回到钱包。`};
  },
  request(s,amount,purpose){
    if(!Number.isSafeInteger(amount)||amount<100)return {ok:false,message:'领取金额从 1 元起，请最多保留两位小数。'};
    if(amount>s.wallet)return {ok:false,message:`目前零钱钱包可取 ${Money.format(s.wallet)} 元，持有中的钱需先按约取回。`};
    s.wallet-=amount;s.requests.unshift({id:`request-${++s.sequence}`,amount,purpose:purpose.trim()||'我的小小计划',status:'pending',date:s.now});
    this.log(s,'发起领取申请',purpose.trim()||'等待家长实际交付',amount,'request');
    return {ok:true,message:'领取申请已交给家长。这笔钱会保留在待领取里。'};
  },
  payRequest(s,id){const r=s.requests.find(r=>r.id===id&&r.status==='pending');if(!r)return {ok:false,message:'这笔领取已经处理过了。'};r.status='paid';s.withdrawn+=r.amount;this.log(s,'这笔钱已实际领取',r.purpose,r.amount,'withdraw');return {ok:true,message:`已确认实际交付 ${Money.format(r.amount)} 元。`};},
  settings(s,budget,rateBps,name){
    const promised=s.bonusEarned+this.reserved(s);
    if(!Number.isSafeInteger(budget)||budget<promised)return {ok:false,message:`预算不能低于已承担及预留的 ${Money.format(promised)} 元，已有承诺需要保留。`};
    if(!Number.isInteger(rateBps)||rateBps<0||rateBps>1000)return {ok:false,message:'原型里的家庭约定年利率请设在 0%–10% 之间。'};
    if(!name.trim()||name.trim().length>8)return {ok:false,message:'孩子的称呼请填写 1–8 个字。'};
    s.budget=budget;s.rateBps=rateBps;s.child=name.trim();
    return {ok:true,message:'家庭约定已更新，只影响之后的新投入与续存。'};
  },
  distributionMode(s,id,mode){const p=s.positions.find(p=>p.id===id&&p.status==='active'&&Products[p.product].type==='income');if(!p||!['cash','reinvest'].includes(mode))return {ok:false,message:'请选择有效的持有计划与分红方式。'};p.distribution=mode;s.distribution=mode;this.log(s,'修改下一次分红方式',mode==='cash'?'收益进零钱钱包，本金按同条件续期':'本金与收益一起按同条件续期',0,'choice');return {ok:true,message:'已更新下一次分红方式，已结算记录不改变。'};},
  schedule(amount,months,first,rateBps){let remaining=amount;const base=Math.floor(amount/months);return Array.from({length:months},(_,i)=>{const principal=i===months-1?remaining:base;const interest=Money.monthInterest(remaining,rateBps);remaining-=principal;return {due:Day.month(first,i),principal,interest,paidPrincipal:0,paidInterest:0,waivedInterest:0};});},
  loanBalance(l){return (l.schedule||[]).reduce((sum,p)=>sum+p.principal-p.paidPrincipal+p.interest-p.paidInterest-p.waivedInterest,0);},
  loanPrincipal(l){return (l.schedule||[]).reduce((sum,p)=>sum+p.principal-p.paidPrincipal,0);},
  loanRequest(s,item,amount,months,first){
    if(!item.trim()||item.trim().length>30)return {ok:false,message:'请写下 1–30 个字的购买用途。'};
    if(!Number.isSafeInteger(amount)||amount<100||amount>100000)return {ok:false,message:'原型预支金额为 1–1000 元，最多两位小数。'};
    if(!Number.isInteger(months)||months<1||months>12)return {ok:false,message:'还款期数请设为 1–12 个月。'};
    if(!Day.valid(first)||first<=s.now)return {ok:false,message:'首次还款日请选择今天之后的有效日期。'};
    if(s.loans.some(l=>['pending','offered','approved','active'].includes(l.status)))return {ok:false,message:'先和家长安排好已有的预支计划，再申请下一笔。'};
    const loan={id:`loan-${++s.sequence}`,item:item.trim(),amount,months,first,rateBps:0,status:'pending',requested:s.now,schedule:[],payments:[]};s.loans.unshift(loan);
    this.log(s,'提交愿望预支申请',item.trim()+'，等待家庭约定，不计入收入或欠款',amount,'loan-request');return {ok:true,loan,message:'申请已交给家长，先看清条件再作决定。'};
  },
  offerLoan(s,id,months,first,rateBps){
    const l=s.loans.find(l=>l.id===id&&['pending','offered'].includes(l.status));if(!l)return {ok:false,message:'这笔申请已经更新。'};
    if(!Number.isInteger(months)||months<1||months>12||!Day.valid(first)||first<=s.now)return {ok:false,message:'请选择 1–12 个月、今天之后的首次还款日。'};
    if(!Number.isInteger(rateBps)||rateBps<0||rateBps>1200)return {ok:false,message:'原型约定年利率范围为 0%–12%，可以无息。'};
    Object.assign(l,{months,first,rateBps,schedule:this.schedule(l.amount,months,first,rateBps),status:'offered'});return {ok:true,message:'条件与月供表已交给孩子确认，尚未形成欠款。'};
  },
  acceptLoan(s,id){const l=s.loans.find(l=>l.id===id&&l.status==='offered');if(!l)return {ok:false,message:'请先查看家长提出的条件。'};if(l.first<=s.now)return {ok:false,message:'首次还款日已到，请家长重新提出未来的日期。'};l.status='approved';return {ok:true,message:'条件已确认，等家长实际垫付后才开始记欠款。'};},
  cancelLoan(s,id){const l=s.loans.find(l=>l.id===id&&['pending','offered','approved'].includes(l.status));if(!l)return {ok:false,message:'已生效的计划不能撤回。'};l.status='cancelled';return {ok:true,message:'已撤回，账户和本金没有变化。'};},
  rejectLoan(s,id){const l=s.loans.find(l=>l.id===id&&['pending','offered'].includes(l.status));if(!l)return {ok:false,message:'这笔申请已经更新。'};l.status='rejected';return {ok:true,message:'这次暂不预支，孩子已有的钱不受影响。'};},
  fundLoan(s,id){const l=s.loans.find(l=>l.id===id&&l.status==='approved');if(!l)return {ok:false,message:'需要孩子先确认条件，且不能重复垫付。'};if(l.first<=s.now)return {ok:false,message:'还款日期已到，请撤回后重新约定。'};l.status='active';l.funded=s.now;this.log(s,'家长已垫付购买',`${l.item}；借款本金与劳动收入分开，约定年利率 ${(l.rateBps/100).toFixed(2)}%`,l.amount,'loan-funded');return {ok:true,message:'已记录实际垫付，月供计划生效；借款未进入理财钱包。'};},
  repayment(s,id,mode='installment'){
    const l=s.loans.find(l=>l.id===id&&l.status==='active');if(!l)return {ok:false,message:'这份计划已经处理。'};
    const next=l.schedule.find(p=>p.principal>p.paidPrincipal||p.interest>p.paidInterest+p.waivedInterest);
    if(mode!=='settle'&&(!next||next.due>s.now))return {ok:false,message:'本期还款日还没到；若想提前还清，可选择提前结清。'};
    const amount=mode==='settle'?l.schedule.reduce((sum,p)=>sum+p.principal-p.paidPrincipal+(p.due<=s.now?p.interest-p.paidInterest-p.waivedInterest:0),0):next.principal-next.paidPrincipal+next.interest-next.paidInterest;
    if(s.wallet<amount)return {ok:false,message:`这次需要可用零钱 ${Money.format(amount)} 元，钱包不足；不自动扣款，也不新增罚息。`};
    let waived=0;
    for(const p of mode==='settle'?l.schedule:[next]){p.paidPrincipal=p.principal;if(p.due<=s.now)p.paidInterest=p.interest;else{waived+=p.interest-p.paidInterest-p.waivedInterest;p.waivedInterest=p.interest-p.paidInterest;}}
    s.wallet-=amount;s.repaidTotal+=amount;l.payments.push({date:s.now,amount,waived,mode});if(this.loanBalance(l)===0)l.status='paid';
    this.log(s,mode==='settle'?'提前结清预支':'完成本期还款',`${l.item}${waived?`；免除未到期利息 ${Money.format(waived)} 元`:''}`,amount,'repay');return {ok:true,message:`已用零钱偿还 ${Money.format(amount)} 元${waived?`，免除未到期利息 ${Money.format(waived)} 元`:''}。`};
  },
  check(s){
    const assets=this.assets(s);const source=s.laborTotal+s.bonusEarned-s.withdrawn-s.repaidTotal;
    return {资产守恒:assets===source,预算未超承诺:this.budgetFree(s)>=0,钱包非负:s.wallet>=0,总资产:Money.format(assets),资金来源核对:Money.format(source),可用收益预算:Money.format(this.budgetFree(s))};
  },
};
const Family={
  initial(){const first=Engine.initial(),second=Engine.initial();Object.assign(second,{profileId:'xiaohe',pin:'2222',child:'小禾',wallet:3500,laborTotal:3500,positions:[],history:[],budget:1000,goal:9800,goalName:'一套小小建筑积木',weeklyPlan:1000});return {parentPin:'2580',children:[first,second]};},
  advance(family,days){return family.children.map(child=>({profileId:child.profileId,...Engine.advance(child,days)}));},
};
