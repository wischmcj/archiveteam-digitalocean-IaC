const WebSocket = require('ws');
const http = require('http');
const request = require('request');

const client = require('prom-client');

const register = client.register

const port = 3000

const requestHandler = (request, response) => {
  response.end(register.metrics())
}

const server = http.createServer(requestHandler)

server.listen(port, (err) => {
  if (err) {
    return console.log('something bad happened', err)
  }

  console.log('server is listening on ' + port)
})

const hosts = ${nodes}
// const hosts = [
//   '138.197.0.203',
//   '142.93.187.235',
//   '159.203.69.108',
//   '104.248.2.97',
//   '165.227.72.215',
//   '159.203.163.210',
//   '159.203.161.8',
//   '142.93.67.185',
//   '138.197.107.139',
//   '165.227.124.236',
//   '104.248.13.107',
//   '104.248.8.78',
//   '174.138.55.12',
//   '104.248.0.83',
//   '104.248.13.237',
//   '165.227.124.136',
//   '104.248.13.232',
//   '104.248.13.30',
//   '104.248.13.142',
//   '104.248.13.116'
// ]
// The number of ports (number of warriors per host)
const numberOfPorts = ${ports}
// const numberOfPorts = 20

const startingPort = 8000
const ports = []

// add ports sequentially, one for each droplet
for(var i = 1; i < numberOfPorts + 1; i++) {
  ports.push(32770)
}
// Set up basic gauges for data transfer
const sentGauge = new client.Gauge({
  name: 'sent',
  help: 'sent data in bytes',
  labelNames: ['host', 'port', 'version']
});
const receivedGauge = new client.Gauge({
  name: 'received',
  help: 'received data in bytes',
  labelNames: ['host', 'port', 'version']
});
const sendingGauge = new client.Gauge({
  name: 'sending',
  help: 'sending data in bytes',
  labelNames: ['host', 'port', 'version']
});
const receivingGauge = new client.Gauge({
  name: 'receiving',
  help: 'receiving data in bytes',
  labelNames: ['host', 'port', 'version']
});
// Guage for archiveteam items e.g. urls
const itemsGauge = new client.Gauge({
  name: 'items',
  help: 'items being worked on',
  labelNames: ['status']
});

// create map with a key for each item status
// increment vals to show # items in each status
const items = {}
setInterval(() => {
  const count = {}
  Object.keys(items).forEach((k) => {
    const v = items[k]
    if (!count[v.status]) {
      count[v.status] = 1
    } else {
      count[v.status] = count[v.status] + 1
    }
  })
  console.log(count)
  Object.keys(count).forEach((status) => {
    const v = count[status]
    itemsGauge.set({status}, v)
  })
}, 1000)
// 
function listen (host, port) {
  const r1 = Math.floor(Math.random() * 100)
  const r2 = Math.floor(Math.random() * 100)
  const hostport = host+':'+port
  const url = 'ws://'+hostport+'/'+r1+'/'+r2+'/websocket'
  const ws = new WebSocket(url)

  const retry = (err) => {
    console.log('got err', err)
    console.log('trying again in 10 seconds')
    setTimeout(() => {
      listen(host, port)
    }, 1000 * 10)
  }

  ws.on('error', (err) => {
    console.error(err)
    retry(err)
  })
  // standardize file size text
  function bytesToSize(bytes) {
     var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
     if (bytes == 0) return '0 Byte';
     var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
     return Math.round(bytes / Math.pow(1024, i), 2) + ' ' + sizes[i];
  };

 //look for line containing 'Cloning Version', extract following text
  let version = 'unknown'
  const get_version = (callback) => {
    request({
      url:'http://'+hostport+'/api/help',
      auth: {user: '${username}', pass: '${password}'}
      // auth: {user: 'diggan', pass: 'knullam32'}
    }, (err, res, body) => {
      if (err) {
        console.log(err)
        return
      }
      let foundLine = false
      body.split('\n').forEach((line) => {
        if (line.indexOf('Cloning version') !== -1) {
          foundLine = true
          version = line.split(' ')[9]
          if(callback) callback()
        }
      })
      if (!foundLine) {
        console.log(body)
      }
    })
  }
  // define behavior when msgs are recieved 
  // behavior varies based on event name
  setInterval(get_version, 1000 * 60)
  get_version(() => {
    sentGauge.set({host, port, version}, 0)
    receivedGauge.set({host, port, version}, 0)
    sendingGauge.set({host, port, version}, 0)
    receivingGauge.set({host, port, version}, 0)
    ws.on('message', function incoming(data) {
      try {
        const parsed = JSON.parse(JSON.parse(data.substring(1))[0])
        let found = false
        if (parsed.event_name === 'bandwidth') {
          found = true
          const {received, sent} = parsed.message
          const {receiving, sending} = parsed.message
          sentGauge.set({host, port, version}, sent)
          receivedGauge.set({host, port, version}, received)
          sendingGauge.set({host, port, version}, sending)
          receivingGauge.set({host, port, version}, receiving)
        }
        // if (parsed.event_name === 'project.refresh') {
        //   // console.log('project.refresh')
        //   found = true
        //   // console.log(parsed)
        //   let recItems = parsed.message.items
        //   recItems = recItems.map((i) => {
        //     return Object.assign({}, i, {output: 'lots'})
        //   })

        //   // console.log(JSON.stringify(recItems, null, 2))
        //   recItems.forEach((i) => {
        //     let status = 'Unknown'
        //     i.tasks.forEach((t) => {
        //       if (t.status === 'running') {
        //         status = t.name
        //       }
        //     })
        //     // const name = i.name.split(' ')[1]
        //     items[i.id] = {
        //       host,
        //       port,
        //       status
        //     }
        //   })
        // }
        const ignoredMessages = [
          'item.output',
          'timestamp',
          'warrior.status',
          'warrior.broadcast_message',
          // 'warrior.projects_loaded',
          // 'project.refresh'
        ]
        if (ignoredMessages.includes(parsed.event_name)) {
          found = true
        }
        if (parsed.event_name === 'item.task_status') {
          // console.log('item.task_status')
          found = true
          // console.log(parsed)
          const message = parsed.message
          // console.log(message.new_status)
          if (!items[message.item_id]) {
            items[message.item_id] = {
              host,
              port,
              status: 'Unknown'
            }
          }

          items[message.item_id].status = message.new_status
          // if (message.new_status === 'running') {
          // }
          // if (message.new_status === 'completed') {
          //   items[message.item_id].status = 'SendDoneToTracker'
          // }
          // if (message.new_status === 'failed') {
          //   items[message.item_id].status = 'Failed'
          // }
        }

        if (!found) {
          console.log('unknown event', parsed.event_name)
        }
      } catch (err) {
        if (err.toString().indexOf('SyntaxError') === -1) {
          console.log(err)
        }
      }
    })
  })
}

hosts.forEach((host) => {
  ports.forEach((port) => {
    listen(host, port)
  })
})
