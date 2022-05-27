let value: Number;
let expiry;
const rejectsOnTimeout= async () => {


  if(!value || expiry) {
    value = Math.random();
    expiry = setTimeout(() => new Promise((res, rej) => res("")), 1000)
  }
  return value;
}


rejectsOnTimeout().then(console.log);
rejectsOnTimeout().then(console.log);
rejectsOnTimeout().then(console.log);
rejectsOnTimeout().then(console.log);
rejectsOnTimeout().then(console.log);
