// DATA comes from data.js, loaded before this file in index.html

Chart.defaults.font.family = "'Work Sans', sans-serif";
Chart.defaults.color = "#5c5540";

const inkPalette = ['#16233d','#2b3a5c','#a8763e','#7c2d2d','#c99a5b','#5c5540','#8a9bb8','#d7c48a'];

function fmtMoney(n){
  return '£' + Number(n).toLocaleString(undefined,{maximumFractionDigits:0});
}

// Stat strip
const ov = DATA.overview;
const stats = [
  [fmtMoney(ov.total_revenue), 'Total Revenue'],
  [ov.unique_invoices.toLocaleString(), 'Orders'],
  [ov.unique_customers.toLocaleString(), 'Customers'],
  [ov.unique_products.toLocaleString(), 'Products'],
  [ov.unique_countries.toLocaleString(), 'Countries']
];
document.getElementById('statStrip').innerHTML = stats.map(s =>
  `<div class="stub"><span class="num">${s[0]}</span><span class="lbl">${s[1]}</span></div>`
).join('');

// Country chart
new Chart(document.getElementById('countryChart'), {
  type:'bar',
  data:{
    labels: DATA.country_rev.map(d=>d.Country),
    datasets:[{
      data: DATA.country_rev.map(d=>d.SaleRevenue),
      backgroundColor: DATA.country_rev.map((_,i)=> i===0? '#7c2d2d':'#16233d'),
      borderRadius:2
    }]
  },
  options:{
    plugins:{legend:{display:false}, tooltip:{callbacks:{label:c=>fmtMoney(c.raw)}}},
    scales:{ y:{ ticks:{ callback:v=>'£'+(v/1000)+'k' }, grid:{color:'#ddd2ab'} }, x:{grid:{display:false}} }
  }
});

// Product chart (horizontal)
new Chart(document.getElementById('productChart'), {
  type:'bar',
  data:{
    labels: DATA.product_rev.map(d=>d.Description.length>22? d.Description.slice(0,22)+'…': d.Description),
    datasets:[{ data: DATA.product_rev.map(d=>d.SaleRevenue), backgroundColor:'#a8763e', borderRadius:2 }]
  },
  options:{
    indexAxis:'y',
    plugins:{legend:{display:false}, tooltip:{callbacks:{label:c=>fmtMoney(c.raw)}}},
    scales:{ x:{ ticks:{ callback:v=>'£'+(v/1000)+'k' }, grid:{color:'#ddd2ab'} }, y:{grid:{display:false}} }
  }
});

// Weekday chart
new Chart(document.getElementById('weekdayChart'), {
  type:'bar',
  data:{
    labels: DATA.weekday.map(d=>d.label),
    datasets:[{ data: DATA.weekday.map(d=>d.InvoiceNo), backgroundColor:'#2b3a5c', borderRadius:2 }]
  },
  options:{
    plugins:{legend:{display:false}},
    scales:{ y:{grid:{color:'#ddd2ab'}}, x:{grid:{display:false}} }
  }
});

// Month chart
new Chart(document.getElementById('monthChart'), {
  type:'line',
  data:{
    labels: DATA.year_month.map(d=>d.label),
    datasets:[{
      data: DATA.year_month.map(d=>d.InvoiceNo),
      borderColor:'#7c2d2d', backgroundColor:'rgba(124,45,45,0.12)',
      fill:true, tension:0.3, pointRadius:3
    }]
  },
  options:{
    plugins:{legend:{display:false}},
    scales:{ y:{grid:{color:'#ddd2ab'}}, x:{grid:{display:false}, ticks:{maxRotation:45,minRotation:45}} }
  }
});

// Hour chart
new Chart(document.getElementById('hourChart'), {
  type:'line',
  data:{
    labels: DATA.hourly.map(d=>d.Hour+':00'),
    datasets:[{
      data: DATA.hourly.map(d=>d.InvoiceNo),
      borderColor:'#a8763e', backgroundColor:'rgba(168,118,62,0.15)',
      fill:true, tension:0.35, pointRadius:2
    }]
  },
  options:{
    plugins:{legend:{display:false}},
    scales:{ y:{grid:{color:'#ddd2ab'}}, x:{grid:{display:false}} }
  }
});

// Segment chart
new Chart(document.getElementById('segmentChart'), {
  type:'bar',
  data:{
    labels: DATA.segments.map(d=>d.Segment.replace(/_/g,' ')),
    datasets:[{ data: DATA.segments.map(d=>d.Count), backgroundColor: inkPalette, borderRadius:2 }]
  },
  options:{
    indexAxis:'y',
    plugins:{legend:{display:false}},
    scales:{ x:{grid:{color:'#ddd2ab'}}, y:{grid:{display:false}} }
  }
});
