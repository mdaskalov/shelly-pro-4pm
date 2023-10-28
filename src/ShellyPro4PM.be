class ShellyPro4PM

  var relay_names
  var relay_labels

  def init()
    var status = tasmota.cmd("status", true)['Status']
    var device = status['DeviceName']
    self.relay_names = status['FriendlyName']
    self.relay_labels = []

    self.clear_screen()
    self.set_header(device)
    self.set_relays()
    for relay: 0..self.relay_names.size()
      tasmota.add_rule(f"POWER{relay+1}#state", def (value) ShellyPro4PM.update_relay(relay+1,value) end )
    end
    tasmota.add_driver(self)
  end

  def deinit()
    self.del()
  end

  def del()
    for relay: 0..self.relay_names.size()
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

  static def wifi(x, y, percent)

    var bars = 0
    if percent
      if percent >= 20 bars = 1 end
      if percent >= 40 bars = 2 end
      if percent >= 60 bars = 3 end
      if percent >= 80 bars = 4 end
    end
    for ofs: 0..3
      var col = bars > ofs ? 1 : 15
      ShellyPro4PM.display_text(f"[Ci{col}x{x+ofs*4}y{y-ofs*2+10}v{(ofs+1)*2}x{x+ofs*4+1}y{y-ofs*2+10}v{(ofs+1)*2}]")
    end
  end

  def set_header(device)
    self.line(0,"", 1, 4)
    self.update_time()
    self.update_wifi()
  end

  def set_relays()
    var relay = 1
    for n : self.relay_names
      var name = (n == "Tasmota" ? (relay == 4 ? "Display" : f"CH {relay}") : n)
      self.line(relay, name, 0, 1)
      self.update_relay(relay, tasmota.get_power(relay-1))
      relay += 1
    end
  end

  static def update_time()
    ShellyPro4PM.display_text(f"[x3y7Ci1Bi4f1tS]")
  end

  static def update_wifi()
    var wifi = tasmota.wifi()
    var quality = wifi.find("quality")
    ShellyPro4PM.wifi(138, 5, quality)
  end

  static def update_relay(relay, powered)
    ShellyPro4PM.switch(123, relay*21+4, powered)
  end

  def every_second()
    self.update_time()
    self.update_wifi()
  end

end

return ShellyPro4PM
#shelly.del()
#shelly = ShellyPro4PM()