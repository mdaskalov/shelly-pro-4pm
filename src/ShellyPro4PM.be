import string
import math

class ShellyPro4PM

  var deviceName
  var relayNames
  var relayCount
  var relayPowered
  var samples
  var wifiQuality

  def init()
    var status = tasmota.cmd("status", true)['Status']
    self.deviceName = status['DeviceName']
    self.relayNames = status['FriendlyName']
    self.relayCount = self.relayNames.size()
    self.relayPowered = 0
    self.samples = 0
    self.wifiQuality = 0

    self.init_screen()
    # redraw after LVGL splash screen cleanup
    tasmota.set_timer(3000, /-> self.init_screen())

    self.add_relay_rules();
    tasmota.add_driver(self)
  end

  def deinit()
    self.del()
  end

  def del()
    self.remove_relay_rules()
    tasmota.remove_driver(self)
  end

  def add_relay_rules()
    for relay: 0..self.relayCount
      tasmota.add_rule(f"POWER{relay+1}#state", def (value) self.update_relay(relay+1, value) end )
    end
  end

  def remove_relay_rules()
    for relay: 0..self.relayCount
      tasmota.remove_rule(f"POWER{relay+1}#state")
    end
  end

  def display_text(text)
    tasmota.cmd(f"DisplayText {text}", true)
  end

  def clear_screen()
    self.display_text("[Ci1Bi0z]")
  end

  def line(line, fg, bg)
    return f"[x0y{line*21+2}Ci{bg}R160:20]";
  end

  def text(line, text, x, fg, bg)
    return f"[x{x}y{line*21+8}Ci{fg}Bi{bg}f0]{text}"
  end

  def time()
    var x = 123
    var y = 8
    var fg = 1
    var bg = 4
    return f"[x{x}y{y}Ci{fg}Bi{bg}f0t]"
  end

  def active_power(line, powered, active_power)
    var x = 78
    var fg = 0
    var bg = 1
    var text = powered ? f"{active_power:%6.1f}W" : f"{'':%7s}"
    return self.text(line, text, x, fg, bg)
  end

  def switch(line, state)
    var x = 123
    var y = line * 21 + 4
    var width = 30
    var height = width / 2
    var radius = height / 2
    var cX = x + radius + (state ? height : 0)
    var cY = y + radius
    var cR = 5
    var col = state ? 4 : 15
    return f"[x{x}y{y}Ci{col}U{width}:{height}:{radius}x{cX}y{cY}Ci1K{cR}]"
  end

  def wifi_quality(percent)
    var x = 103
    var y = 14
    var bars = 0
    if percent
      if percent >= 20 bars = 1 end
      if percent >= 40 bars = 2 end
      if percent >= 60 bars = 3 end
      if percent >= 80 bars = 4 end
    end
    var cmd = ""
    for bar: 0..3
      var col = bars > bar ? 1 : 15
      cmd += f"Ci{col}x{x+bar*4}y{y-bar*2}v{(bar+1)*2}x{x+bar*4+1}y{y-bar*2}v{(bar+1)*2}"
    end
    return f"[{cmd}]"
  end

  def status()
    var averageQuality = self.samples == 0 ? 0 : self.wifiQuality / self.samples
    var cmd = self.wifi_quality(averageQuality)
    cmd += self.time()
    return cmd;
  end

  def update_relay(relay, powered)
    var cmd = self.switch(relay, powered)
    var bit = int(math.pow(2, relay-1))
    if powered
      self.relayPowered |= bit
    else
      self.relayPowered &= (0xF ^ bit)
    end
    cmd += self.active_power(relay, powered, 0)
    self.display_text(cmd)
  end

  def update_status_line()
    self.display_text(self.status())
    self.samples = 0
    self.wifiQuality = 0
  end

  def update_active_power()
    var cmd = ""
    var power = tasmota.cmd("status 10", true)["StatusSNS"]["ENERGY"]["Power"]
    for i: 0..power.size()-1
      if tasmota.get_power(i)
        cmd += self.active_power(i+1, true, power[i])
      end
    end
    print(cmd)
    self.display_text(cmd)
  end

  def sample_wifi_quality()
    var wifi = tasmota.wifi()
    var quality = wifi.find("quality")
    self.wifiQuality += quality ? quality : 0
    self.samples += 1
  end

  def init_screen()
    var xTxt = 3
    var fgHeader = 1
    var bgHeader = 4
    var fgLine = 0
    var bgLine = 1
    self.clear_screen()
    var cmd = self.line(0, fgHeader, bgHeader)
    cmd += self.text(0, self.deviceName, xTxt, fgHeader, bgHeader)
    self.sample_wifi_quality()
    cmd += self.status()
    self.relayPowered = 0
    var line = 1
    for n : self.relayNames
      var defaultName = (n == "" || string.find(n,"Tasmota") == 0)
      var displayRelay = line == self.relayCount
      var name = (defaultName ? (displayRelay ? "Display" : f"CH {line}") : n)
      cmd += self.line(line, fgLine, bgLine)
      cmd += self.text(line, name, xTxt, fgLine, bgLine)
      var powered = tasmota.get_power(line-1)
      if !displayRelay
        self.relayPowered |= (powered ? int(math.pow(2, line-1)) : 0)
      end
      cmd += self.switch(line, powered)
      line += 1
    end
    self.display_text(cmd)
  end

  def every_second()
    var rtc = tasmota.rtc()['local']
    var secs = tasmota.time_dump(rtc)['sec']
    if secs == 0 || self.samples >= 6 # update every minute
      self.update_status_line()
    elif secs % 10 == 0 # sample every 10s
      self.sample_wifi_quality()
    elif self.relayPowered != 0 # every second if powered
      self.update_active_power()
    end
  end

end

return ShellyPro4PM
