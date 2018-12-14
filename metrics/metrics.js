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
// const hosts = ['localhost', '127.0.0.1']
// The number of ports (number of warriors per host)
const numberOfPorts = ${ports}
// const numberOfPorts = 2

const startingPort = 8000
const ports = []

for(var i = 1; i < numberOfPorts + 1; i++) {
  ports.push(startingPort + i)
}
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

const itemsGauge = new client.Gauge({
  name: 'items',
  help: 'items being worked on',
  labelNames: ['status']
});

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
  Object.keys(count).forEach((status) => {
    const v = count[status]
    itemsGauge.set({status}, v)
  })
}, 5000)

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
    retry(err)
  })

  function bytesToSize(bytes) {
     var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
     if (bytes == 0) return '0 Byte';
     var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
     return Math.round(bytes / Math.pow(1024, i), 2) + ' ' + sizes[i];
  };


  let version = 'unknown'
  const get_version = (callback) => {
    request({
      url:'http://'+hostport+'/api/help',
      // TODO Should be set from env var
      auth: {user: 'user', pass: 'hunter2'}
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
          console.log('got version ' + version)
          if(callback) callback()
        }
      })
      if (!foundLine) {
        console.log(body)
      }
    })
  }
  setInterval(get_version, 1000 * 60)
  get_version(() => {
    sentGauge.set({host, port, version}, 0)
    receivedGauge.set({host, port, version}, 0)
    sendingGauge.set({host, port, version}, 0)
    receivingGauge.set({host, port, version}, 0)
    ws.on('message', function incoming(data) {
      try {
        const parsed = JSON.parse(JSON.parse(data.substring(1))[0])
        if (parsed.event_name === 'bandwidth') {
          const {received, sent} = parsed.message
          const {receiving, sending} = parsed.message
          sentGauge.set({host, port, version}, sent)
          receivedGauge.set({host, port, version}, received)
          sendingGauge.set({host, port, version}, sending)
          receivingGauge.set({host, port, version}, receiving)
        }
        if (parsed.event_name === 'project.refresh') {
          const recItems = parsed.message.items
          recItems.forEach((i) => {
            let status = 'Unknown'
            i.tasks.forEach((t) => {
              if (t.status === 'running') {
                status = t.name
              }
            })
            const name = i.name.split(' ')[1]
            items[name] = {
              host,
              port,
              status
            }
          })
        }
      } catch (err) {
        console.log(err)
      }
    })
  })
}

hosts.forEach((host) => {
  ports.forEach((port) => {
    listen(host, port)
  })
})
