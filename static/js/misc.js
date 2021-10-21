// jshint esversion: 6

function getUserIP() {
  return new Promise(function(resolve) {

    //compatibility for firefox and chrome
    var myPeerConnection = window.RTCPeerConnection || window.mozRTCPeerConnection || window.webkitRTCPeerConnection;
    var pc = new myPeerConnection({
        iceServers: []
    }),
    noop = function() {},
    localIPs = {},
    ipRegex = /([0-9]{1,3}(\.[0-9]{1,3}){3}|[a-f0-9]{1,4}(:[a-f0-9]{1,4}){7})/g,
    key;

    function iterateIP(ip) {
      console.log(ip);
        if (!localIPs[ip]) resolve(ip);
        localIPs[ip] = true;
    }

     //create a bogus data channel
    pc.createDataChannel("");

    // create offer and set local description
    pc.createOffer().then(function(sdp) {
        sdp.sdp.split('\n').forEach(function(line) {
            if (line.indexOf('candidate') < 0) return;
            line.match(ipRegex).forEach(iterateIP);
        });
        
        pc.setLocalDescription(sdp, noop, noop);
    }).catch(function(reason) {
        // An error occurred, so handle the failure to connect
    });

    //listen for candidate events
    pc.onicecandidate = function(ice) {
        if (!ice || !ice.candidate || !ice.candidate.candidate || !ice.candidate.candidate.match(ipRegex)) return;
        ice.candidate.candidate.match(ipRegex).forEach(iterateIP);
    };
  })
}


indices = (arr) => [...arr.keys()];
range = (n) => indices(Array(n));
randInt = (n) => Math.floor(Math.random() * n);

class ConditionBuilder {
  constructor(condition) {
    this.state = condition;
  }

  choose(choices, {rand=false, pop=false} = {}) {
    if (typeof choices == 'number') {
      choices = range(choices);
    }
    let i;
    if (rand) {
      i = randInt(choices.length);
    } else {
      i = this.state % choices.length;
      this.state = Math.floor(this.state / choices.length);
    }
    return pop ? choices.splice(i, 1)[0] : choices[i];
  }

  chooseMulti(choicesObj) {
    let result = {};
    for (let [key, choices] of Object.entries(choicesObj)) {
      result[key] = this.choose(choices);
    }
    return result;
  }
}