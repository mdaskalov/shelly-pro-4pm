import string

class ShellyPro4PM

  var deviceName
  var relayNames
  var secs
  var wifi_sum
  var wifi_cnt

  def init()
    var status = tasmota.cmd("status", true)['Status']
    self.deviceName = status['DeviceName']
    self.relayNames = status['FriendlyName']
    self.secs = 0
    self.wifi_sum = 0
    self.wifi_cnt = 0

    self.init_screen()
    # redraw after LVGL splash screen cleanup
    tasmota.set_timer(3000, /-> self.init_screen())

    for relay: 0..self.relayNames.size()
      tasmota.add_rule(f"POWER{relay+1}#state", def (value) ShellyPro4PM.update_relay(relay+1,value) end )
    end
    tasmota.add_driver(self)
  end

  def deinit()
    self.del()
  end

  def del()
    for relay: 0..self.relayNames.size()
      tasmota.remove_rule(f"POWER{relay+1}#state")
    end
    tasmota.remove_driver(self)
  end

  static def display_text(text)
    tasmota.cmd(f"DisplayText {text}", true)
  end

  static def clear_screen()
    ShellyPro4PM.display_text("[Bi0z]")
  end

  static def line(line, text, fg, bg)
    ShellyPro4PM.display_text(f"[x0y{line*21+2}Ci{bg}R160:20x3y{line*21+7}Ci{fg}Bi{bg}f1]{text}")
  end

  static def switch(x, y, state)
    var width = 30
    var height = width / 2
    var radius = height / 2
    var cX = x + radius + (state ? height : 0)
    var cY = y + radius + 1
    var cR = 5
    var col = state ? 4 : 15
    ShellyPro4PM.display_text(f"[x{x}y{y+1}Ci{col}U{width}:{height}:{radius}x{cX}y{cY}Ci1K{cR}]")
  end

  static def status(x, y, percent)
    var bars = 0
    if percent
      if percent >= 20 bars = 1 end
      if percent >= 40 bars = 2 end
      if percent >= 60 bars = 3 end
      if percent >= 80 bars = 4 end
    end
    var cmd = ""
    for ofs: 0..3
      var col = bars > ofs ? 1 : 15
      cmd += f"Ci{col}x{x+ofs*4}y{y-ofs*2+10}v{(ofs+1)*2}x{x+ofs*4+1}y{y-ofs*2+10}v{(ofs+1)*2}"
    end
    cmd += f"x{x+20}y{y+2}Ci1Bi4f1t"
    ShellyPro4PM.display_text(f"[{cmd}]")
  end

  def set_header()
    self.line(0, self.deviceName, 1, 4)
    self.status(100, 5, 0)
  end

  def set_relays()
    var relay = 1
    for n : self.relayNames
      var defaultName = (n == "" || string.find(n,"Tasmota") == 0)
      var lastRelay = relay == self.relayNames.size()
      var name = (defaultName ? (lastRelay ? "Display" : f"CH {relay}") : n)
      self.line(relay, name, 0, 1)
      self.update_relay(relay, tasmota.get_power(relay-1))
      relay += 1
    end
  end

  def init_screen()
    self.clear_screen()
    self.set_header()
    self.set_relays()
  end

  static def update_relay(relay, powered)
    ShellyPro4PM.switch(123, relay*21+4, powered)
  end

  def every_second()

    self.secs += 1

    if self.secs % 10 == 0
      var wifi = tasmota.wifi()
      var quality = wifi.find("quality")
      self.wifi_sum += quality ? quality : 0
      self.wifi_cnt += 1
    end

    if self.secs > 59
      var avrg = self.wifi_sum / self.wifi_cnt
      self.status(100, 5, avrg)

      self.wifi_sum = 0
      self.wifi_cnt = 0

      var rtc = tasmota.rtc()['local']
      self.secs = tasmota.time_dump(rtc)['sec']
    end
  end

end

return ShellyPro4PM
# shelly.del()
# shelly = ShellyPro4PM()