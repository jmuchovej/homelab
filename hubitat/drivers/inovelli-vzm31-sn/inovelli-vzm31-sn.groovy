/* groovylint-disable CompileStatic, LineLength, NglParseError, NoDef, UnusedImport */
/**
 *  Inovelli Dimmer (Blue, VZM31-SN) - Device Driver for Hubitat Elevation
 *
 *     Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 *     in compliance with the License. You may obtain a copy of the License at:
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 *     Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
 *     on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 *     for the specific language governing permissions and limitations under the License.
 *
 *  Standard clusters through the rbn libraries (on/off, level, energy, power) plus Inovelli's private cluster
 *  0xFC31 for parameters and the Zigbee group bindings that make a switch and its bulbs one unit.
 *  Scene-button commands and LED effects on 0xFC31 are not implemented yet and are ignored quietly.
 *
 *  Parameters: the device is the source of truth. `refresh` reads every parameter in the table into the
 *  matching `parameter<N>` preference and into state.parameters; Save Preferences writes only the parameters
 *  whose preference differs from the value the device last reported, then reads them back; `configure`
 *  writes nothing on 0xFC31. A parameter never read from the device is never written.
 *
 *  `voltage` and `amperage` capabilities come from rbn.meter; this device does not report them.
 *  The device reports energy (0x0702:0x0000) in hundredths of a kWh and power (0x0B04:0x050B) in tenths of a
 *  watt, where rbn.meter assumes tenths and whole units; the two customParse* methods below apply the
 *  device's scale and hand everything else to the library.
 *
 *  Fingerprints, parameter definitions, and the metering scale are taken from Inovelli's driver,
 *  https://github.com/InovelliUSA/Hubitat (Drivers/inovelli-dimmer-blue-series-vzm31-sn.src).
 *
 * ver. 0.1.0  2026-10-02 rbn  - standard clusters only
 * ver. 0.1.1  2026-10-02 rbn  - runtime validated on a VZM31-SN (refresh, on/off, physical switch and dim, power ÷10, energy ÷100, 0xFC31 ignored)
 * ver. 0.2.0  2026-10-03 rbn  - parameters as preferences (device is the source of truth); bindGroup/unbindGroup/readBindings for switch-plus-bulbs units
 */

static String version() { '0.1.1' }
static String timeStamp() { '2026/10/02 04:36 PM' }

@Field static final Boolean _DEBUG = false

import groovy.transform.Field
import hubitat.device.HubMultiAction
import hubitat.device.Protocol
import hubitat.helper.HexUtils
import hubitat.zigbee.zcl.DataType
import java.util.concurrent.ConcurrentHashMap
import groovy.json.JsonOutput

deviceType = 'Dimmer'
@Field static final String DEVICE_TYPE = 'Dimmer'

#include rbn.common
#include rbn.switch
#include rbn.level
#include rbn.meter
#include rbn.reporting

@Field static final Integer PRIVATE_CLUSTER = 0xFC31
@Field static final Map INOVELLI = [mfgCode: '0x122F']
@Field static final Integer SHORT_DELAY = 300
@Field static final Integer LONG_DELAY = 1000          // mode changes (52, 258) make the device reconfigure itself
@Field static final List<Integer> MODE_PARAMETERS = [52, 258]

// Inovelli's dimming/ramp parameters share one range: 0 = instant, 5..126 = tenths of a second,
// 127 = sync with another parameter (every one but parameter 1).
static Map<String, String> rateOptions(final boolean sync) {
    Map<String, String> options = ['0': 'instant']
    (5..126).each { Integer tenths -> options["${tenths}"] = String.format('%.1f s', tenths / 10.0) }
    if (sync) { options['127'] = 'sync (see description)' }
    return options
}

// Static methods, not @Field constants: a @Field initialiser cannot reference another @Field in a Hubitat script.
static Map<String, String> ledColors() {
    return ['0': 'Red', '14': 'Orange', '35': 'Lemon', '64': 'Lime', '85': 'Green', '106': 'Teal', '127': 'Cyan', '149': 'Aqua', '170': 'Blue', '191': 'Violet', '212': 'Magenta', '234': 'Pink', '255': 'White']
}

static Map<String, String> onOff() { return ['0': 'Disabled', '1': 'Enabled'] }

// number -> [name, size (bits), default, and one of: options (enum) | range (number); readOnly rows become attributes]
@Field static final Map<Integer, Map> Parameters = [
    1:   [name: 'Dimming Speed - Up (Remote)',      size: 8,  default: 25,   options: rateOptions(false)],
    2:   [name: 'Dimming Speed - Up (Local)',       size: 8,  default: 127,  options: rateOptions(true), sync: 1],
    3:   [name: 'Ramp Rate - Off to On (Remote)',   size: 8,  default: 127,  options: rateOptions(true), sync: 1],
    4:   [name: 'Ramp Rate - Off to On (Local)',    size: 8,  default: 127,  options: rateOptions(true), sync: 3],
    5:   [name: 'Dimming Speed - Down (Remote)',    size: 8,  default: 127,  options: rateOptions(true), sync: 1],
    6:   [name: 'Dimming Speed - Down (Local)',     size: 8,  default: 127,  options: rateOptions(true), sync: 2],
    7:   [name: 'Ramp Rate - On to Off (Remote)',   size: 8,  default: 127,  options: rateOptions(true), sync: 3],
    8:   [name: 'Ramp Rate - On to Off (Local)',    size: 8,  default: 127,  options: rateOptions(true), sync: 4],
    // scale: 'level' rows are stored on the device as 0..254 (254 = 100 %) with 255 meaning "previous level" (shown as 101).
    9:   [name: 'Minimum Level',                    size: 8,  default: 1,    range: '1..99',  scale: 'level', unit: '%'],
    10:  [name: 'Maximum Level',                    size: 8,  default: 100,  range: '2..100', scale: 'level', unit: '%'],
    12:  [name: 'Auto Off Timer',                   size: 16, default: 0,    range: '0..32767', unit: 's; 0 = disabled'],
    13:  [name: 'Default Level (Local)',            size: 8,  default: 101,  range: '1..101', scale: 'level', unit: '%; 101 = previous level'],
    14:  [name: 'Default Level (Remote)',           size: 8,  default: 101,  range: '1..101', scale: 'level', unit: '%; 101 = previous level'],
    15:  [name: 'Level After Power Restored',       size: 8,  default: 101,  range: '0..101', scale: 'level', unit: '%; 0 = off, 101 = previous level'],
    18:  [name: 'Active Power Reports',             size: 8,  default: 10,   range: '0..100', unit: '% change; 0 = disabled'],
    19:  [name: 'Periodic Power & Energy Reports',  size: 16, default: 3600, range: '0..32767', unit: 's; 0 = disabled'],
    20:  [name: 'Energy Reports',                   size: 16, default: 10,   range: '0..32767', unit: 'x 0.01 kWh change; 0 = disabled'],
    21:  [name: 'Power Source',                     size: 1,  readOnly: true, attribute: 'powerSource', options: ['0': 'non-neutral', '1': 'neutral']],
    30:  [name: 'Aux Medium Gear Learn Value',      size: 8,  readOnly: true, attribute: 'auxMediumGear'],
    31:  [name: 'Aux Low Gear Learn Value',         size: 8,  readOnly: true, attribute: 'auxLowGear'],
    32:  [name: 'Internal Temperature',             size: 8,  readOnly: true, attribute: 'internalTemp', unit: '°C'],
    33:  [name: 'Overheat',                         size: 1,  readOnly: true, attribute: 'overHeat', options: ['0': 'no', '1': 'yes']],
    50:  [name: 'Button Press Delay',               size: 8,  default: 5,    options: ['0': '0 ms', '3': '300 ms', '4': '400 ms', '5': '500 ms', '6': '600 ms', '7': '700 ms', '8': '800 ms', '9': '900 ms']],
    52:  [name: 'Smart Bulb Mode',                  size: 1,  default: 0,    options: onOff()],
    95:  [name: 'LED Bar Color (when On)',          size: 8,  default: 170,  options: ledColors()],
    96:  [name: 'LED Bar Color (when Off)',         size: 8,  default: 170,  options: ledColors()],
    97:  [name: 'LED Bar Intensity (when On)',      size: 8,  default: 33,   range: '0..100'],
    98:  [name: 'LED Bar Intensity (when Off)',     size: 8,  default: 3,    range: '0..100'],
    99:  [name: 'All LED Notification',             size: 32, default: 0,    range: '0..4294967295'],
    100: [name: 'LED Bar Scaling',                  size: 1,  default: 0,    options: ['0': 'Gen3 (VZM)', '1': 'Gen2 (LZW)']],
    256: [name: 'Local Protection',                 size: 1,  default: 0,    options: ['0': 'local control enabled', '1': 'local control disabled']],
    257: [name: 'Remote Protection',                size: 1,  readOnly: true, attribute: 'remoteProtection', options: ['0': 'remote control enabled', '1': 'remote control disabled']],
    258: [name: 'Switch Mode',                      size: 1,  default: 1,    options: ['0': 'dimmer', '1': 'on/off']],
]

metadata {
    definition(
        name: 'Inovelli Dimmer (Blue, VZM31-SN)',
        importUrl: 'https://raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/drivers/inovelli-vzm31-sn/inovelli-vzm31-sn.bundled.groovy',
        namespace: 'rbn', author: 'John Muchovej', singleThreaded: true)
    {
        capability 'Sensor'

        attribute 'powerSource', 'string'
        attribute 'internalTemp', 'number'
        attribute 'overHeat', 'string'
        attribute 'remoteProtection', 'string'
        attribute 'auxMediumGear', 'number'
        attribute 'auxLowGear', 'number'
        attribute 'bindings', 'string'

        command 'bindGroup', [[name: 'Group id*', type: 'NUMBER', description: 'Zigbee group id (decimal). For a Hubitat group with Zigbee group messaging on, it is the number in the group device\'s DNI Group_<n>']]
        command 'unbindGroup', [[name: 'Group id*', type: 'NUMBER', description: 'Zigbee group id (decimal) to unbind endpoint 2 from']]
        command 'readBindings'
        command 'bind', [[name: 'Command string*', type: 'STRING', description: 'A raw zdo bind/unbind or he raw command, relayed to the device as-is']]
    }

    fingerprint profileId:'0104', endpointId:'01', inClusters:'0000,0003,0004,0005,0006,0008,0702,0B04,0B05,FC57,FC31', outClusters:'0003,0019',           model:'VZM31-SN', manufacturer:'Inovelli', deviceJoinName: 'Inovelli Dimmer (Blue)'
    fingerprint profileId:'0104', endpointId:'02', inClusters:'0000,0003',                                              outClusters:'0003,0019,0006,0008', model:'VZM31-SN', manufacturer:'Inovelli', deviceJoinName: 'Inovelli Dimmer (Blue)'

    preferences {
        input name: 'txtEnable', type: 'bool', title: '<b>Enable descriptionText logging</b>', defaultValue: true, description: '<i>Enables command logging.</i>'
        input name: 'logEnable', type: 'bool', title: '<b>Enable debug logging</b>', defaultValue: true, description: '<i>Turns on debug logging for 24 hours.</i>'
        Parameters.each { Integer number, Map p ->
            if (p.readOnly) { return }
            String detail = "P${number}; device default ${p.default}"
            if (p.unit) { detail += "; ${p.unit}" }
            if (p.sync) { detail += "; 127 = sync with parameter ${p.sync}" }
            if (p.options) {
                input name: "parameter${number}", type: 'enum', title: "<b>${p.name}</b>", options: p.options, description: "<i>${detail}</i>"
            } else {
                input name: "parameter${number}", type: 'number', title: "<b>${p.name}</b>", range: p.range, description: "<i>${detail}; range ${p.range}</i>"
            }
        }
    }
}

// ----- refresh: standard reads plus every table parameter, as one dispatch -----

List<String> customRefresh() {
    List<String> cmds = zigbee.onOffRefresh() + zigbee.levelRefresh() + zigbee.readAttribute(0x0702, 0x0000) + zigbee.readAttribute(0x0B04, 0x050B)
    Parameters.keySet().each { Integer number -> cmds += zigbee.readAttribute(PRIVATE_CLUSTER, number, INOVELLI, 200) }
    logDebug "customRefresh() : ${cmds.size()} commands"
    return cmds
}

// ----- metering scale -----

// 0x0702:0x0000 CurrentSummationDelivered, hundredths of a kWh on this device.
boolean customParseMeteringCluster(final Map descMap) {
    if (descMap.attrId == '0000' && descMap.value != null && descMap.value != 'FFFF') {
        BigDecimal energy = new BigDecimal(hexStrToUnsignedInt(descMap.value)).movePointLeft(2)
        logDebug "customParseMeteringCluster: energy raw 0x${descMap.value} -> ${energy} kWh"
        sendEnergyEvent(energy)
        return true
    }
    return standardParseMeteringCluster(descMap)
}

// 0x0B04:0x050B ActivePower, tenths of a watt on this device.
boolean customParseElectricalMeasureCluster(final Map descMap) {
    if (descMap.attrId == '050B' && descMap.value != null && descMap.value != 'FFFF') {
        BigDecimal power = new BigDecimal(hexStrToUnsignedInt(descMap.value)).movePointLeft(1)
        logDebug "customParseElectricalMeasureCluster: power raw 0x${descMap.value} -> ${power} W"
        sendPowerEvent(power)
        return true
    }
    return standardParseElectricalMeasureCluster(descMap)
}

// ----- parameters: 0xFC31 attribute reports and read responses -----

void customParseInovelliPrivateCluster(final Map descMap) {
    if (descMap.isClusterSpecific == true || descMap.attrInt == null) {
        logDebug "customParseInovelliPrivateCluster: command 0x${descMap.command} data=${descMap.data} (scene buttons and LED events are not implemented in this version)"
        return
    }
    if (descMap.value == null) { return }
    Integer number = descMap.attrInt as Integer
    Integer value = decodeParameter(descMap.value, descMap.encoding)
    Map p = Parameters[number]
    if (p == null) {
        logDebug "customParseInovelliPrivateCluster: parameter ${number} = ${value} (not in the table)"
        return
    }
    if (p.scale == 'level') { value = byteToPercent(value) }
    rememberParameter(number, value)
    if (p.readOnly) {
        String shown = p.options ? (p.options["${value}"] ?: "${value}") : "${value}"
        sendEvent(name: p.attribute, value: shown, unit: p.unit, descriptionText: "${p.name} is ${shown}")
        logInfo "${p.name} is ${shown}${p.unit ? ' ' + p.unit : ''} (P${number})"
    } else {
        String name = "parameter${number}".toString()
        String before = settings."${name}"?.toString()
        device.updateSetting(name, [value: value.toString(), type: p.options ? 'enum' : 'number'])
        String after = settings."${name}"?.toString()
        if (before != value.toString()) {
            logInfo "P${number} ${p.name}: preference ${before ?: 'unset'} -> ${value} from the device (stored now: ${after ?: 'unset'})"
        } else {
            logDebug "P${number} ${p.name} = ${value} (preference already matches the device)"
        }
    }
}

// Inovelli stores level parameters as 0..254 (254 = 100 %) and uses 255 for "previous level", shown as 101.
private static Integer byteToPercent(final Integer value) {
    Integer clamped = Math.min(Math.max(value, 0), 255)
    if (clamped >= 255) { return 101 }
    return Math.ceil(clamped / 255 * 100) as Integer
}

private static Integer percentToByte(final Integer value) {
    Integer clamped = Math.min(Math.max(value, 0), 101)
    if (clamped >= 101) { return 255 }
    Integer raw = Math.floor(clamped / 100 * 255) as Integer
    return raw >= 255 ? 254 : raw
}

// Signed types report two's complement; everything else is unsigned.
// Not static: hexStrToUnsignedInt is an instance method the hub injects.
private Integer decodeParameter(final String hex, final String encoding) {
    Integer raw = hexStrToUnsignedInt(hex)
    if (encoding == '28' && raw > 0x7F) { return raw - 0x100 }        // int8
    if (encoding == '29' && raw > 0x7FFF) { return raw - 0x10000 }    // int16
    return raw
}

private void rememberParameter(final Integer number, final Integer value) {
    if (state.parameters == null) { state.parameters = [:] }
    state.parameters["${number}"] = value                             // state keys are strings once serialised
}

private Integer lastReadParameter(final Integer number) {
    Object value = state.parameters?."${number}"
    return value == null ? null : (value as Integer)
}

private Integer preferredParameter(final Integer number) {
    Object value = settings."parameter${number}"
    if (value == null || "${value}".trim() == '') { return null }
    return new BigDecimal("${value}").intValue()
}

private static Integer zclTypeForSize(final Integer size) {
    switch (size) {
        case 1:  return 0x10    // boolean
        case 16: return 0x21    // uint16
        case 32: return 0x23    // uint32
        default: return 0x20    // uint8
    }
}

// Save Preferences: write only what differs from the device's last reported value, then read it back.
void customUpdated() {
    List<String> cmds = []
    List<Integer> written = []
    List<Integer> unread = []
    Parameters.each { Integer number, Map p ->
        if (p.readOnly) { return }
        Integer wanted = preferredParameter(number)
        if (wanted == null) { return }
        Integer current = lastReadParameter(number)
        if (current == null) { unread << number; return }
        if (current == wanted) { return }
        Integer delay = number in MODE_PARAMETERS ? LONG_DELAY : SHORT_DELAY
        Integer raw = p.scale == 'level' ? percentToByte(wanted) : wanted
        cmds += zigbee.writeAttribute(PRIVATE_CLUSTER, number, zclTypeForSize(p.size as Integer), raw, INOVELLI, delay)
        written << number
    }
    if (unread) { logWarn "customUpdated: parameters ${unread} have not been read from the device yet; press refresh before changing them (nothing written)" }
    if (!written) { logDebug 'customUpdated: no parameter changes'; return }
    written.each { Integer number -> cmds += zigbee.readAttribute(PRIVATE_CLUSTER, number, INOVELLI, SHORT_DELAY) }
    logInfo "customUpdated: writing parameters ${written}"
    sendZigbeeCommands(cmds)
}

// ----- bindings: endpoint 2 -> Zigbee group, and the binding table -----

void bindGroup(final BigDecimal groupId) {
    logInfo "bindGroup(${groupId})"
    sendZigbeeCommands(groupBindingCommands('bind', groupId.intValue()) + bindingTableRequest(0))
}

void unbindGroup(final BigDecimal groupId) {
    logInfo "unbindGroup(${groupId})"
    sendZigbeeCommands(groupBindingCommands('unbind', groupId.intValue()) + bindingTableRequest(0))
}

void readBindings() {
    logInfo 'readBindings()'
    state.remove('bindingsPartial')
    sendZigbeeCommands(bindingTableRequest(0))
}

void bind(final String command) {
    logInfo "bind: relaying ${command}"
    sendZigbeeCommands([command])
}

private List<String> groupBindingCommands(final String action, final Integer groupId) {
    String group = zigbee.convertToHexString(groupId, 4)
    return [
        "zdo ${action} 0x${device.deviceNetworkId} 0x02 0x01 0x0006 {${device.zigbeeId}} {${group}}", 'delay 500',
        "zdo ${action} 0x${device.deviceNetworkId} 0x02 0x01 0x0008 {${device.zigbeeId}} {${group}}", 'delay 3000',
    ]
}

// ZDO Mgmt_Bind_req (0x0033): sequence byte, start index. The reply is ZDO 0x8033.
private List<String> bindingTableRequest(final Integer startIndex) {
    return ["he raw 0x${device.deviceNetworkId} 0 0 0x0033 {00 ${zigbee.convertToHexString(startIndex, 2)}} {0x0000}"]
}

void customParseZdoClusters(final Map descMap) {
    if (descMap.clusterInt != 0x8033) { return }
    List<String> data = descMap.data as List<String>
    Integer status = hexStrToUnsignedInt(data[1])
    if (status != 0) {
        logWarn "binding table request failed with ZDO status 0x${data[1]}"
        return
    }
    Integer total = hexStrToUnsignedInt(data[2])
    Integer start = hexStrToUnsignedInt(data[3])
    Integer count = hexStrToUnsignedInt(data[4])
    List<String> entries = start == 0 ? [] : ((state.bindingsPartial ?: []) as List<String>)
    Integer i = 5
    count.times {
        Integer sourceEndpoint = hexStrToUnsignedInt(data[i + 8])
        String cluster = data[i + 10] + data[i + 9]
        Integer mode = hexStrToUnsignedInt(data[i + 11])
        i += 12
        if (mode == 0x01) {
            entries << "EP${sourceEndpoint} 0x${cluster} -> group 0x${data[i + 1]}${data[i]}"
            i += 2
        } else if (mode == 0x03) {
            String destination = data[i..(i + 7)].reverse().join('')
            entries << "EP${sourceEndpoint} 0x${cluster} -> ${destination} EP${hexStrToUnsignedInt(data[i + 8])}"
            i += 9
        } else {
            entries << "EP${sourceEndpoint} 0x${cluster} -> unknown address mode 0x${data[i - 1]}"
        }
    }
    if (start + count < total) {
        state.bindingsPartial = entries
        sendZigbeeCommands(bindingTableRequest(start + count))
        return
    }
    state.remove('bindingsPartial')
    String summary = entries ? entries.join('; ') : 'none'
    sendEvent(name: 'bindings', value: JsonOutput.toJson(entries), descriptionText: "${total} binding(s): ${summary}")
    logInfo "bindings (${total}): ${summary}"
}
