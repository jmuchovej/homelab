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

// #include rbn.common  -- included at line 376
// #include rbn.switch  -- included at line 1618
// #include rbn.level  -- included at line 1861
// #include rbn.meter  -- included at line 2089
// #include rbn.reporting  -- included at line 2327

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
// /////////////////////////////////////////////////////////////////// Libraries //////////////////////////////////////////////////////////////////////

// ~~~~~ start include rbn.common ~~~~~
library( // rbn.common#L2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Common ZCL Library', name: 'common', namespace: 'rbn', // rbn.common#L3
    importUrl: '', documentationLink: '', // rbn.common#L4
    version: '4.1.1' // rbn.common#L5
) // rbn.common#L6
/*
  *  Common ZCL Library
  *
  *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except
  *  in compliance with the License. You may obtain a copy of the License at:
  *
  *      http://www.apache.org/licenses/LICENSE-2.0
  *
  *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
  *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
  *  for the specific language governing permissions and limitations under the License.
  *
  *  Forked from https://github.com/kkossev/Hubitat (Libraries/commonLib.groovy) at commit 0bf47407.
  *  Modified for the rbn namespace: Tuya code path removed (0xEF00 cluster handling, E00x pre-parsers in parse(),
  *  Tuya command builders and constants, tuyaTest/tuyaBlackMagic/queryAllTuyaDP, isTuya/updateTuyaVersion); identity;
  *  ClustersMap gains 0xFC31 'InovelliPrivate' so the Inovelli VZM31-SN driver's customParseInovelliPrivateCluster() is dispatched.
  *
  * This library is inspired by @w35l3y work on Tuya device driver (Edge project).
  * For a big portions of code all credits go to Jonathan Bradshaw.
  *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/common.groovy#L28-L52
*/

String commonLibVersion() { '4.1.1' } // rbn.common#L55
String commonLibStamp() { '2026/08/23 4:28 PM' } // rbn.common#L56

import groovy.transform.Field // rbn.common#L58
import hubitat.device.HubMultiAction // rbn.common#L59
import hubitat.device.Protocol // rbn.common#L60
import hubitat.helper.HexUtils // rbn.common#L61
import hubitat.zigbee.zcl.DataType // rbn.common#L62
import java.util.concurrent.ConcurrentHashMap // rbn.common#L63
import groovy.json.JsonOutput // rbn.common#L64
import groovy.transform.CompileStatic // rbn.common#L65
import java.math.BigDecimal // rbn.common#L66

metadata { // rbn.common#L68
        if (_DEBUG) { // rbn.common#L69
            command 'test', [[name: 'test', type: 'STRING', description: 'test', defaultValue : '']] // rbn.common#L70
            command 'testParse', [[name: 'testParse', type: 'STRING', description: 'testParse', defaultValue : '']] // rbn.common#L71
        } // rbn.common#L72

        capability 'Configuration' // rbn.common#L75
        capability 'Refresh' // rbn.common#L76
        capability 'HealthCheck' // rbn.common#L77
        capability 'PowerSource' // rbn.common#L78

        attribute 'healthStatus', 'enum', ['unknown', 'offline', 'online'] // rbn.common#L81
        attribute 'rtt', 'number' // rbn.common#L82
        attribute '_status_', 'string' // rbn.common#L83

        command 'configure', [[name:"✋ This button can not configure battery-powered 'sleepy' devices. Pair the device again to your hub, without deleting it!"]] // rbn.common#L88
        command 'deviceUtilities', [[name:'⚙️ Advanced administrative and diagnostic commands • Use only when troubleshooting or reconfiguring the device', type: 'ENUM', constraints: ConfigureOpts.keySet() as List<String>]] // rbn.common#L89

        command 'loadAllDefaults', [[name:'⚠️ Erases all preferences, states, scheduled jobs and child devices, then reloads the driver defaults • Use after switching drivers, or when the device was not recognised by an older version']] // rbn.common#L91
        command 'ping', [[name:'📶 Test device connectivity and measure response time • Updates the RTT attribute with round-trip time in milliseconds']] // rbn.common#L92
        command 'refresh', [[name:"🔄 Query the device for current state and update the attributes. • ⚠️ Battery-powered 'sleepy' devices may not respond!"]] // rbn.common#L93

        fingerprint profileId:'0104', endpointId:'F2', inClusters:'', outClusters:'', model:'unknown', manufacturer:'unknown', deviceJoinName: 'Zigbee device affected by Hubitat F2 bug' // rbn.common#L96

    preferences { // rbn.common#L98

        if (device) { // rbn.common#L103
            input name: 'advancedOptions', type: 'bool', title: '<b>Advanced Options</b>', description: 'The advanced options should be already automatically set in an optimal way for your device...Click on the "Save and Close" button when toggling this option!', defaultValue: false // rbn.common#L104
            if (advancedOptions == true) { // rbn.common#L105
                input name: 'healthCheckMethod', type: 'enum', title: '<b>Healthcheck Method</b>', options: HealthcheckMethodOpts.options, defaultValue: HealthcheckMethodOpts.defaultValue, required: true, description: 'Method to check device online/offline status.' // rbn.common#L106
                input name: 'healthCheckInterval', type: 'enum', title: '<b>Healthcheck Interval</b>', options: HealthcheckIntervalOpts.options, defaultValue: HealthcheckIntervalOpts.defaultValue, required: true, description: 'How often the hub will check the device health.<br>3 consecutive failures will result in status "offline"' // rbn.common#L107
                input name: 'ignoreDuplicatedZigbeeMessages', type: 'bool', title: '<b>Ignore Duplicated Zigbee Messages</b>', defaultValue: false, description: 'Ignore identical Zigbee attribute reports received within short time periods to reduce log spam and redundant processing' // rbn.common#L108
                input name: 'traceEnable', type: 'bool', title: '<b>Enable trace logging</b>', defaultValue: false, description: 'Turns on detailed extra trace logging for 30 minutes.' // rbn.common#L109
            } // rbn.common#L110
        } // rbn.common#L111
    } // rbn.common#L112
} // rbn.common#L113

@Field static final Integer IGNORE_DUPLICATED_ZIGBEE_MESSAGES_TIMER = 1000 // rbn.common#L115
@Field static final Integer DIGITAL_TIMER = 5000 // rbn.common#L116
@Field static final Integer REFRESH_TIMER = 6000 // rbn.common#L117
@Field static final Integer DEBOUNCING_TIMER = 300 // rbn.common#L118
@Field static final Integer COMMAND_TIMEOUT = 10 // rbn.common#L119
@Field static final Integer MAX_PING_MILISECONDS = 10000 // rbn.common#L120
@Field static final String  UNKNOWN = 'UNKNOWN' // rbn.common#L121
@Field static final Integer DEFAULT_MIN_REPORTING_TIME = 10 // rbn.common#L122
@Field static final Integer DEFAULT_MAX_REPORTING_TIME = 3600 // rbn.common#L123
@Field static final Integer PRESENCE_COUNT_THRESHOLD = 3 // rbn.common#L124
@Field static final int DELAY_MS = 200 // rbn.common#L125
@Field static final Integer INFO_AUTO_CLEAR_PERIOD = 60 // rbn.common#L126

@Field static final Map HealthcheckMethodOpts = [ // rbn.common#L128
    defaultValue: 1, options: [0: 'Disabled', 1: 'Activity check', 2: 'Periodic polling'] // rbn.common#L129
] // rbn.common#L130
@Field static final Map HealthcheckIntervalOpts = [ // rbn.common#L131
    defaultValue: 240, options: [2: 'Every 2 Mins', 10: 'Every 10 Mins', 30: 'Every 30 Mins', 60: 'Every 1 Hour', 240: 'Every 4 Hours', 720: 'Every 12 Hours'] // rbn.common#L132
] // rbn.common#L133

@Field static final Map ConfigureOpts = [ // rbn.common#L135
    '*** LOAD ALL DEFAULTS ***'  : [key:0, function: 'loadAllDefaults'], // rbn.common#L136
    'Configure the device'       : [key:2, function: 'configureNow'], // rbn.common#L137
    'Reset Statistics'           : [key:9, function: 'resetStatistics'], // rbn.common#L138
    'Delete All Preferences'     : [key:4, function: 'deleteAllSettings'], // rbn.common#L139
    'Delete All Current States'  : [key:5, function: 'deleteAllCurrentStates'], // rbn.common#L140
    'Delete All Scheduled Jobs'  : [key:6, function: 'deleteAllScheduledJobs'], // rbn.common#L141
    'Delete All State Variables' : [key:7, function: 'deleteAllStates'], // rbn.common#L142
    'Delete All Child Devices'   : [key:8, function: 'deleteAllChildDevices'] // rbn.common#L143
] // rbn.common#L144

public boolean isVirtual() { device.controllerType == null || device.controllerType == '' } // rbn.common#L146

public void parse(final String description) { // rbn.common#L152
    Map stateCopy = state // rbn.common#L153
    checkDriverVersion(stateCopy) // rbn.common#L154
    if (state.stats != null) { state.stats?.rxCtr= (state.stats?.rxCtr ?: 0) + 1 } else { state.stats = [:] } // rbn.common#L155
    if (state.lastRx != null) { state.lastRx?.timeStamp = unix2formattedDate(now()) } else { state.lastRx = [:] } // rbn.common#L156
    unscheduleCommandTimeoutCheck(state) // rbn.common#L157
    setHealthStatusOnline(state) // rbn.common#L158

    if (description?.startsWith('zone status')  || description?.startsWith('zone report')) { // rbn.common#L160
        logDebug "parse: zone status: $description" // rbn.common#L161
        if (this.respondsTo('customParseIasMessage')) { customParseIasMessage(description) } // rbn.common#L162
        else if (this.respondsTo('standardParseIasMessage')) { standardParseIasMessage(description) } // rbn.common#L163
        else if (this.respondsTo('parseIasMessage')) { parseIasMessage(description) } // rbn.common#L164
        else { logDebug "ignored IAS zone status (no IAS parser) description: $description" } // rbn.common#L165
        return // rbn.common#L166
    } // rbn.common#L167
    else if (description?.startsWith('enroll request')) { // rbn.common#L168
        logDebug "parse: enroll request: $description" // rbn.common#L169

        if (settings?.logEnable) { logInfo 'Sending IAS enroll response...' } // rbn.common#L171
        List<String> cmds = zigbee.enrollResponse() + zigbee.readAttribute(0x0500, 0x0000) // rbn.common#L172
        logDebug "enroll response: ${cmds}" // rbn.common#L173
        sendZigbeeCommands(cmds) // rbn.common#L174
        return // rbn.common#L175
    } // rbn.common#L176

    final Map descMap = myParseDescriptionAsMap(description) // rbn.common#L178

    if (!isChattyDeviceReport(descMap)) { logDebug "parse: descMap = ${descMap} description=${description }" } // rbn.common#L180
    if (isSpammyDeviceReport(descMap)) { return } // rbn.common#L181

    if (descMap.profileId == '0000') { // rbn.common#L183
        parseZdoClusters(descMap) // rbn.common#L184
        return // rbn.common#L185
    } // rbn.common#L186
    if (descMap.isClusterSpecific == false) { // rbn.common#L187
        parseGeneralCommandResponse(descMap) // rbn.common#L188
        return // rbn.common#L189
    } // rbn.common#L190

    if (standardAndCustomParseCluster(descMap, description)) { return } // rbn.common#L192

    switch (descMap.clusterInt as Integer) { // rbn.common#L194
        case 0x000C : // rbn.common#L195
            if (this.respondsTo('customParseAnalogInputClusterDescription')) { // rbn.common#L196
                customParseAnalogInputClusterDescription(descMap, description) // rbn.common#L197
                descMap.remove('additionalAttrs')?.each { final Map map -> customParseAnalogInputClusterDescription(descMap + map, description) } // rbn.common#L198
            } // rbn.common#L199
            break // rbn.common#L200
        case 0x0300 : // rbn.common#L201
            if (this.respondsTo('standardParseColorControlCluster')) { // rbn.common#L202
                standardParseColorControlCluster(descMap, description) // rbn.common#L203
                descMap.remove('additionalAttrs')?.each { final Map map -> standardParseColorControlCluster(descMap + map, description) } // rbn.common#L204
            } // rbn.common#L205
            break // rbn.common#L206
        default: // rbn.common#L207
            if (settings.logEnable) { // rbn.common#L208

                String clusterHex = descMap.cluster ?: descMap.clusterId ?: zigbee.convertToHexString(descMap.clusterInt as Integer, 4) // rbn.common#L210
                logWarn "parse: zigbee received <b>unknown cluster:0x${clusterHex} (${descMap.clusterInt})</b> message (${descMap})" // rbn.common#L211
            } // rbn.common#L212
            break // rbn.common#L213
    } // rbn.common#L214
} // rbn.common#L215

@Field static final Map<Integer, String> ClustersMap = [ // rbn.common#L217
    0x0000: 'Basic',             0x0001: 'Power',            0x0003: 'Identify',         0x0004: 'Groups',           0x0005: 'Scenes',       0x0006: 'OnOff',           0x0007:'onOffConfiguration',      0x0008: 'LevelControl', // rbn.common#L218
    0x000C: 'AnalogInput',       0x0012: 'MultistateInput',  0x0020: 'PollControl',      0x0102: 'WindowCovering',   0x0201: 'Thermostat',  0x0204: 'ThermostatConfig', // rbn.common#L219
    0x0400: 'Illuminance',       0x0402: 'Temperature',      0x0405: 'Humidity',         0x0406: 'Occupancy',        0x042A: 'Pm25',         0x0500: 'IAS',             0x0702: 'Metering', // rbn.common#L220
    0x0B04: 'ElectricalMeasure', 0xE001: 'E0001',            0xE002: 'E002',             0xEC03: 'EC03',             0xFC03: 'FC03',            0xFC11: 'FC11',            0xFC7E: 'AirQualityIndex', // rbn.common#L221
    0xFC80: 'FC80',              0xFC81: 'FC81',             0xFCC0: 'XiaomiFCC0',       0xED00: 'ED00',             0xFC31: 'InovelliPrivate' // rbn.common#L222
] // rbn.common#L223

boolean standardAndCustomParseCluster(Map descMap, final String description) { // rbn.common#L227
    Integer clusterInt = descMap.clusterInt as Integer // rbn.common#L228
    String  clusterName = ClustersMap[clusterInt] ?: UNKNOWN // rbn.common#L229

    String  clusterHex = descMap.cluster ?: descMap.clusterId ?: zigbee.convertToHexString(clusterInt, 4) // rbn.common#L231
    if (clusterName == null || clusterName == UNKNOWN) { // rbn.common#L232
        logWarn "standardAndCustomParseCluster: zigbee received <b>unknown cluster:0x${clusterHex} (${clusterInt})</b> message (${descMap})" // rbn.common#L233
        return false // rbn.common#L234
    } // rbn.common#L235
    String customParser = "customParse${clusterName}Cluster" // rbn.common#L236

    if (this.respondsTo(customParser)) { // rbn.common#L238
        this."${customParser}"(descMap) // rbn.common#L239
        descMap.remove('additionalAttrs')?.each { final Map map -> this."${customParser}"(descMap + map) } // rbn.common#L240
        return true // rbn.common#L241
    } // rbn.common#L242
    String standardParser = "standardParse${clusterName}Cluster" // rbn.common#L243

    if (this.respondsTo(standardParser)) { // rbn.common#L245
        this."${standardParser}"(descMap) // rbn.common#L246
        descMap.remove('additionalAttrs')?.each { final Map map -> this."${standardParser}"(descMap + map) } // rbn.common#L247
        return true // rbn.common#L248
    } // rbn.common#L249
    if (device?.getDataValue('model') != 'ZigUSB' && descMap.cluster != '0300') { // rbn.common#L250
        logWarn "standardAndCustomParseCluster: <b>Missing</b> ${standardParser} or ${customParser} handler for <b>cluster:0x${clusterHex} (${clusterInt})</b> message (${descMap})" // rbn.common#L251
    } // rbn.common#L252
    return false // rbn.common#L253
} // rbn.common#L254

private static void updateRxStats(final Map state) { // rbn.common#L257
    if (state.stats != null) { state.stats['rxCtr'] = (state.stats['rxCtr'] ?: 0) + 1 } else { state.stats = [:] } // rbn.common#L258
} // rbn.common#L259

public boolean isChattyDeviceReport(final Map descMap)  { // rbn.common#L261
    if (_TRACE_ALL == true) { return false } // rbn.common#L262
    if (this.respondsTo('isSpammyDPsToNotTrace')) { // rbn.common#L263
        return isSpammyDPsToNotTrace(descMap) // rbn.common#L264
    } // rbn.common#L265
    return false // rbn.common#L266
} // rbn.common#L267

public boolean isSpammyDeviceReport(final Map descMap) { // rbn.common#L269
    if (_TRACE_ALL == true) { return false } // rbn.common#L270
    if (this.respondsTo('isSpammyDPsToIgnore')) { // rbn.common#L271
        return isSpammyDPsToIgnore(descMap) // rbn.common#L272
    } // rbn.common#L273
    return false // rbn.common#L274
} // rbn.common#L275

@Field static final Map<Integer, String> ZdoClusterEnum = [ // rbn.common#L277
    0x0002: 'Node Descriptor Request',  0x0005: 'Active Endpoints Request',   0x0006: 'Match Descriptor Request',  0x0022: 'Unbind Request',  0x0013: 'Device announce', 0x0034: 'Management Leave Request', // rbn.common#L278
    0x8002: 'Node Descriptor Response', 0x8004: 'Simple Descriptor Response', 0x8005: 'Active Endpoints Response', 0x801D: 'Extended Simple Descriptor Response', 0x801E: 'Extended Active Endpoint Response', // rbn.common#L279
    0x8021: 'Bind Response',            0x8022: 'Unbind Response',            0x8023: 'Bind Register Response',    0x8034: 'Management Leave Response' // rbn.common#L280
] // rbn.common#L281

private void parseZdoClusters(final Map descMap) { // rbn.common#L284
    if (state.stats == null) { state.stats = [:] } // rbn.common#L285
    final Integer clusterId = descMap.clusterInt as Integer // rbn.common#L286
    final String clusterName = ZdoClusterEnum[clusterId] ?: "UNKNOWN_CLUSTER (0x${descMap.clusterId})" // rbn.common#L287
    final String statusHex = ((List)descMap.data)[1] // rbn.common#L288
    final Integer statusCode = hexStrToUnsignedInt(statusHex) // rbn.common#L289
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${statusHex}" // rbn.common#L290
    final String clusterInfo = "${device.displayName} Received ZDO ${clusterName} (0x${descMap.clusterId}) status ${statusName}" // rbn.common#L291
    List<String> cmds = [] // rbn.common#L292
    switch (clusterId) { // rbn.common#L293
        case 0x0005 : // rbn.common#L294
            state.stats['activeEpRqCtr'] = (state.stats['activeEpRqCtr'] ?: 0) + 1 // rbn.common#L295
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, data:${descMap.data})" } // rbn.common#L296

            cmds += ["he raw ${device.deviceNetworkId} 0 0 0x8005 {00 00 00 00 01 01} {0x0000}"] // rbn.common#L298
            sendZigbeeCommands(cmds) // rbn.common#L299
            break // rbn.common#L300
        case 0x0006 : // rbn.common#L301
            state.stats['matchDescCtr'] = (state.stats['matchDescCtr'] ?: 0) + 1 // rbn.common#L302
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Input cluster count:${descMap.data[5]} Input cluster: 0x${descMap.data[7] + descMap.data[6]})" } // rbn.common#L303
            cmds += ["he raw ${device.deviceNetworkId} 0 0 0x8006 {00 00 00 00 00} {0x0000}"] // rbn.common#L304
            sendZigbeeCommands(cmds) // rbn.common#L305
            break // rbn.common#L306
        case 0x0013 : // rbn.common#L307
            state.stats['rejoinCtr'] = (state.stats['rejoinCtr'] ?: 0) + 1 // rbn.common#L308
            if (settings?.logEnable) { log.debug "${clusterInfo}, rejoinCtr= ${state.stats['rejoinCtr']}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Device network ID: ${descMap.data[2] + descMap.data[1]}, Capability Information: ${descMap.data[11]})" } // rbn.common#L309
            break // rbn.common#L310
        case 0x8004 : // rbn.common#L311
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, status:${descMap.data[1]}, lenght:${hubitat.helper.HexUtils.hexStringToInt(descMap.data[4])}" } // rbn.common#L312
            if (this.respondsTo('parseSimpleDescriptorResponse')) { parseSimpleDescriptorResponse(descMap) } // rbn.common#L313
            break // rbn.common#L314
        case 0x8005 : // rbn.common#L315
            String endpointCount = descMap.data[4] // rbn.common#L316
            String endpointList = descMap.data[5] // rbn.common#L317
            if (settings?.logEnable) { log.debug "${clusterInfo}, (endpoint response) endpointCount = ${endpointCount}  endpointList = ${endpointList}" } // rbn.common#L318
            break // rbn.common#L319
        case 0x8021 : // rbn.common#L320
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Status: ${descMap.data[1] == '00' ? 'Success' : '<b>Failure</b>'})" } // rbn.common#L321
            break // rbn.common#L322
        case 0x0002 : // rbn.common#L323
        case 0x0036 : // rbn.common#L324
        case 0x8022 : // rbn.common#L325
        case 0x8034 : // rbn.common#L326
            if (settings?.logEnable) { log.debug "${device.displayName} Unprocessed ZDO command: cluster=${descMap.clusterId} command=${descMap.command} attrId=${descMap.attrId} value=${descMap.value} data=${descMap.data}" } // rbn.common#L327
            break // rbn.common#L328
        default : // rbn.common#L329
            if (settings?.logEnable) { log.warn "${device.displayName} Unprocessed ZDO command: cluster=${descMap.clusterId} command=${descMap.command} attrId=${descMap.attrId} value=${descMap.value} data=${descMap.data}" } // rbn.common#L330
            break // rbn.common#L331
    } // rbn.common#L332
    if (this.respondsTo('customParseZdoClusters')) { customParseZdoClusters(descMap) } // rbn.common#L333
} // rbn.common#L334

private void parseGeneralCommandResponse(final Map descMap) { // rbn.common#L337
    final int commandId = hexStrToUnsignedInt(descMap.command) // rbn.common#L338
    switch (commandId) { // rbn.common#L339
        case 0x01: parseReadAttributeResponse(descMap); break // rbn.common#L340
        case 0x04: parseWriteAttributeResponse(descMap); break // rbn.common#L341
        case 0x07: parseConfigureResponse(descMap); break // rbn.common#L342
        case 0x09: parseReadReportingConfigResponse(descMap); break // rbn.common#L343
        case 0x0B: parseDefaultCommandResponse(descMap); break // rbn.common#L344
        default: // rbn.common#L345
            final String commandName = ZigbeeGeneralCommandEnum[commandId] ?: "UNKNOWN_COMMAND (0x${descMap.command})" // rbn.common#L346
            final String clusterName = clusterLookup(descMap.clusterInt) // rbn.common#L347
            final String status = descMap.data in List ? ((List)descMap.data).last() : descMap.data // rbn.common#L348
            final int statusCode = hexStrToUnsignedInt(status) // rbn.common#L349
            final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${status}" // rbn.common#L350
            if (statusCode > 0x00) { // rbn.common#L351
                log.warn "zigbee ${commandName} ${clusterName} error: ${statusName}" // rbn.common#L352
            } else if (settings.logEnable) { // rbn.common#L353
                log.trace "zigbee ${commandName} ${clusterName}: ${descMap.data}" // rbn.common#L354
            } // rbn.common#L355
            break // rbn.common#L356
    } // rbn.common#L357
} // rbn.common#L358

private void parseReadAttributeResponse(final Map descMap) { // rbn.common#L361
    final List<String> data = descMap.data as List<String> // rbn.common#L362
    final String attribute = data[1] + data[0] // rbn.common#L363
    final int statusCode = hexStrToUnsignedInt(data[2]) // rbn.common#L364
    final String status = ZigbeeStatusEnum[statusCode] ?: "0x${data}" // rbn.common#L365
    if (statusCode > 0x00) { // rbn.common#L366
        logWarn "zigbee read ${clusterLookup(descMap.clusterInt)} attribute 0x${attribute} error: ${status}" // rbn.common#L367
    } // rbn.common#L368
    else { // rbn.common#L369
        logDebug "zigbee read ${clusterLookup(descMap.clusterInt)} attribute 0x${attribute} response: ${status} ${data}" // rbn.common#L370
    } // rbn.common#L371
} // rbn.common#L372

private void parseWriteAttributeResponse(final Map descMap) { // rbn.common#L375
    final String data = descMap.data in List ? ((List)descMap.data).first() : descMap.data // rbn.common#L376
    final int statusCode = hexStrToUnsignedInt(data) // rbn.common#L377
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${data}" // rbn.common#L378
    if (statusCode > 0x00) { // rbn.common#L379
        logWarn "zigbee response write ${clusterLookup(descMap.clusterInt)} attribute error: ${statusName}" // rbn.common#L380
    } // rbn.common#L381
    else { // rbn.common#L382
        logDebug "zigbee response write ${clusterLookup(descMap.clusterInt)} attribute response: ${statusName}" // rbn.common#L383
    } // rbn.common#L384
} // rbn.common#L385

private void parseConfigureResponse(final Map descMap) { // rbn.common#L388

    final String status = ((List)descMap.data).first() // rbn.common#L390
    final int statusCode = hexStrToUnsignedInt(status) // rbn.common#L391
    if (statusCode == 0x00 && settings.enableReporting != false) { // rbn.common#L392
        state.reportingEnabled = true // rbn.common#L393
    } // rbn.common#L394
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${status}" // rbn.common#L395
    if (statusCode > 0x00) { // rbn.common#L396
        log.warn "zigbee configure reporting error: ${statusName} ${descMap.data}" // rbn.common#L397
    } else { // rbn.common#L398
        logDebug "zigbee configure reporting response: ${statusName} ${descMap.data}" // rbn.common#L399
    } // rbn.common#L400
} // rbn.common#L401

private void parseReadReportingConfigResponse(final Map descMap) { // rbn.common#L404
    int status = zigbee.convertHexToInt(descMap.data[0]) // rbn.common#L405

    if (status == 0) { // rbn.common#L407

        int min = zigbee.convertHexToInt(descMap.data[6]) * 256 + zigbee.convertHexToInt(descMap.data[5]) // rbn.common#L409
        int max = zigbee.convertHexToInt(descMap.data[8] + descMap.data[7]) // rbn.common#L410
        int delta = 0 // rbn.common#L411
        if (descMap.data.size() >= 11) { // rbn.common#L412
            delta = zigbee.convertHexToInt(descMap.data[10] + descMap.data[9]) // rbn.common#L413
        } // rbn.common#L414
        else if (descMap.data.size() == 10) { // rbn.common#L415
            delta = zigbee.convertHexToInt(descMap.data[9]) // rbn.common#L416
        } // rbn.common#L417
        else { // rbn.common#L418
            logTrace "descMap.data.size = ${descMap.data.size()}" // rbn.common#L419
        } // rbn.common#L420
        logDebug "Received Read Reporting Configuration Response (0x09) for cluster:${descMap.clusterId} attribute:${descMap.data[3] + descMap.data[2]}, data=${descMap.data} (Status: ${descMap.data[0] == '00' ? 'Success' : '<b>Failure</b>'}) min=${min} max=${max} delta=${delta}" // rbn.common#L421
    } // rbn.common#L422
    else { // rbn.common#L423
        logWarn "<b>Not Found (0x8b)</b> Read Reporting Configuration Response for cluster:${descMap.clusterId} attribute:${descMap.data[3] + descMap.data[2]}, data=${descMap.data} (Status: ${descMap.data[0] == '00' ? 'Success' : '<b>Failure</b>'})" // rbn.common#L424
    } // rbn.common#L425
} // rbn.common#L426

private Boolean executeCustomHandler(String handlerName, Object handlerArgs) { // rbn.common#L428
    if (!this.respondsTo(handlerName)) { // rbn.common#L429
        logTrace "executeCustomHandler: function <b>${handlerName}</b> not found" // rbn.common#L430
        return false // rbn.common#L431
    } // rbn.common#L432

    Boolean result = false // rbn.common#L434
    try { // rbn.common#L435
        result = "$handlerName"(handlerArgs) // rbn.common#L436
    } // rbn.common#L437
    catch (e) { // rbn.common#L438
        logWarn "executeCustomHandler: Exception '${e}'caught while processing <b>$handlerName</b>(<b>$handlerArgs</b>) (val=${fncmd}))" // rbn.common#L439
        return false // rbn.common#L440
    } // rbn.common#L441

    return result // rbn.common#L443
} // rbn.common#L444

private void parseDefaultCommandResponse(final Map descMap) { // rbn.common#L447
    final List<String> data = descMap.data as List<String> // rbn.common#L448
    final String commandId = data[0] // rbn.common#L449
    final int statusCode = hexStrToUnsignedInt(data[1]) // rbn.common#L450
    final String status = ZigbeeStatusEnum[statusCode] ?: "0x${data[1]}" // rbn.common#L451
    if (statusCode > 0x00) { // rbn.common#L452
        logWarn "zigbee ${clusterLookup(descMap.clusterInt)} command 0x${commandId} error: ${status}" // rbn.common#L453
    } else { // rbn.common#L454
        logDebug "zigbee ${clusterLookup(descMap.clusterInt)} command 0x${commandId} response: ${status}" // rbn.common#L455

        if (this.respondsTo('customParseDefaultCommandResponse')) { // rbn.common#L457
            customParseDefaultCommandResponse(descMap) // rbn.common#L458
        } // rbn.common#L459
    } // rbn.common#L460
} // rbn.common#L461

@Field static final int ATTRIBUTE_READING_INFO_SET = 0x0000 // rbn.common#L464
@Field static final int FIRMWARE_VERSION_ID = 0x4000 // rbn.common#L465
@Field static final int PING_ATTR_ID = 0x01 // rbn.common#L466

@Field static final Map<Integer, String> ZigbeeStatusEnum = [ // rbn.common#L468
    0x00: 'Success', 0x01: 'Failure', 0x02: 'Not Authorized', 0x80: 'Malformed Command', 0x81: 'Unsupported COMMAND', 0x85: 'Invalid Field', 0x86: 'Unsupported Attribute', 0x87: 'Invalid Value', 0x88: 'Read Only', // rbn.common#L469
    0x89: 'Insufficient Space', 0x8A: 'Duplicate Exists', 0x8B: 'Not Found', 0x8C: 'Unreportable Attribute', 0x8D: 'Invalid Data Type', 0x8E: 'Invalid Selector', 0x94: 'Time out', 0x9A: 'Notification Pending', 0xC3: 'Unsupported Cluster' // rbn.common#L470
] // rbn.common#L471

@Field static final Map<Integer, String> ZigbeeGeneralCommandEnum = [ // rbn.common#L473
    0x00: 'Read Attributes', 0x01: 'Read Attributes Response', 0x02: 'Write Attributes', 0x03: 'Write Attributes Undivided', 0x04: 'Write Attributes Response', 0x05: 'Write Attributes No Response', 0x06: 'Configure Reporting', // rbn.common#L474
    0x07: 'Configure Reporting Response', 0x08: 'Read Reporting Configuration', 0x09: 'Read Reporting Configuration Response', 0x0A: 'Report Attributes', 0x0B: 'Default Response', 0x0C: 'Discover Attributes', 0x0D: 'Discover Attributes Response', // rbn.common#L475
    0x0E: 'Read Attributes Structured', 0x0F: 'Write Attributes Structured', 0x10: 'Write Attributes Structured Response', 0x11: 'Discover Commands Received', 0x12: 'Discover Commands Received Response', 0x13: 'Discover Commands Generated', // rbn.common#L476
    0x14: 'Discover Commands Generated Response', 0x15: 'Discover Attributes Extended', 0x16: 'Discover Attributes Extended Response' // rbn.common#L477
] // rbn.common#L478

@Field static final int ROLLING_AVERAGE_N = 10 // rbn.common#L480
private BigDecimal approxRollingAverage(BigDecimal avgPar, BigDecimal newSample) { // rbn.common#L481
    BigDecimal avg = avgPar // rbn.common#L482
    if (avg == null || avg == 0) { avg = newSample } // rbn.common#L483
    avg -= avg / ROLLING_AVERAGE_N // rbn.common#L484
    avg += newSample / ROLLING_AVERAGE_N // rbn.common#L485
    return avg // rbn.common#L486
} // rbn.common#L487

private void handlePingResponse() { // rbn.common#L489
    Long now = new Date().getTime() // rbn.common#L490
    if (state.lastRx == null) { state.lastRx = [:] } // rbn.common#L491
    state.lastRx['checkInTime'] = now // rbn.common#L492

    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: '0').toInteger() // rbn.common#L494
    if (timeRunning > 0 && timeRunning < MAX_PING_MILISECONDS) { // rbn.common#L495
        state.stats['pingsOK'] = (state.stats['pingsOK'] ?: 0) + 1 // rbn.common#L496
        if (timeRunning < safeToInt((state.stats['pingsMin'] ?: '9999'))) { state.stats['pingsMin'] = timeRunning } // rbn.common#L497
        if (timeRunning > safeToInt((state.stats['pingsMax'] ?: '0')))   { state.stats['pingsMax'] = timeRunning } // rbn.common#L498
        state.stats['pingsAvg'] = approxRollingAverage(safeToDouble(state.stats['pingsAvg']), safeToDouble(timeRunning)) as int // rbn.common#L499
        sendRttEvent() // rbn.common#L500
    } // rbn.common#L501
    else { // rbn.common#L502
        logWarn "unexpected ping timeRunning=${timeRunning} " // rbn.common#L503
    } // rbn.common#L504
    state.states['isPing'] = false // rbn.common#L505
} // rbn.common#L506

@Field static final Map powerSourceOpts =  [ defaultValue: 0, options: [0: 'unknown', 1: 'mains', 2: 'mains', 3: 'battery', 4: 'dc', 5: 'emergency mains', 6: 'emergency mains']] // rbn.common#L513

private void standardParseBasicCluster(final Map descMap) { // rbn.common#L516
    Long now = new Date().getTime() // rbn.common#L517
    if (state.lastRx == null) { state.lastRx = [:] } // rbn.common#L518
    state.lastRx['checkInTime'] = now // rbn.common#L519
    boolean isPing = state.states?.isPing ?: false // rbn.common#L520
    switch (descMap.attrInt as Integer) { // rbn.common#L521
        case 0x0000: // rbn.common#L522
            logDebug "Basic cluster: ZCLVersion = ${descMap?.value}" // rbn.common#L523
            break // rbn.common#L524
        case PING_ATTR_ID: // rbn.common#L525
            if (isPing) { // rbn.common#L526
                handlePingResponse() // rbn.common#L527
            } // rbn.common#L528
            else { // rbn.common#L529
                logTrace "Tuya check-in message (attribute ${descMap.attrId} reported: ${descMap.value})" // rbn.common#L530
            } // rbn.common#L531
            break // rbn.common#L532
        case 0x0004: // rbn.common#L533
            logDebug "received device manufacturer ${descMap?.value}" // rbn.common#L534

            String manufacturer = device.getDataValue('manufacturer') // rbn.common#L536
            if ((manufacturer == null || manufacturer == 'unknown') && (descMap?.value != null)) { // rbn.common#L537
                logWarn "updating device manufacturer from ${manufacturer} to ${descMap?.value}" // rbn.common#L538
                device.updateDataValue('manufacturer', descMap?.value) // rbn.common#L539
            } // rbn.common#L540
            break // rbn.common#L541
        case 0x0005: // rbn.common#L542
            if (isPing) { // rbn.common#L543
                handlePingResponse() // rbn.common#L544
            } // rbn.common#L545
            else { // rbn.common#L546
                logDebug "received device model ${descMap?.value}" // rbn.common#L547

                String model = device.getDataValue('model') // rbn.common#L549
                if ((model == null || model == 'unknown') && (descMap?.value != null)) { // rbn.common#L550
                    logWarn "updating device model from ${model} to ${descMap?.value}" // rbn.common#L551
                    device.updateDataValue('model', descMap?.value) // rbn.common#L552
                } // rbn.common#L553
            } // rbn.common#L554
            break // rbn.common#L555
        case 0x0007: // rbn.common#L556
            String powerSourceReported = powerSourceOpts.options[descMap?.value as int] // rbn.common#L557
            logDebug "received Power source <b>${powerSourceReported}</b> (${descMap?.value})" // rbn.common#L558
            String currentPowerSource = device.getDataValue('powerSource') // rbn.common#L559
            if (currentPowerSource == null || currentPowerSource == 'unknown') { // rbn.common#L560
                logInfo "updating device powerSource from ${currentPowerSource} to ${powerSourceReported}" // rbn.common#L561
                sendEvent(name: 'powerSource', value: powerSourceReported, type: 'physical') // rbn.common#L562
            } // rbn.common#L563
            break // rbn.common#L564
        case 0xFFDF: // rbn.common#L565
            logDebug "Tuya check-in (Cluster Revision=${descMap?.value})" // rbn.common#L566
            break // rbn.common#L567
        case 0xFFE2: // rbn.common#L568
            logDebug "Tuya check-in (AppVersion=${descMap?.value})" // rbn.common#L569
            break // rbn.common#L570
        case [0xFFE0, 0xFFE1, 0xFFE3, 0xFFE4] : // rbn.common#L571
            logTrace "Tuya attribute ${descMap?.attrId} value=${descMap?.value}" // rbn.common#L572
            break // rbn.common#L573
        case 0xFFFE: // rbn.common#L574
            logTrace "Tuya attributeReportingStatus (attribute FFFE) value=${descMap?.value}" // rbn.common#L575
            break // rbn.common#L576
        case FIRMWARE_VERSION_ID: // rbn.common#L577
            final String version = descMap.value ?: 'unknown' // rbn.common#L578
            logInfo "device firmware version is ${version}" // rbn.common#L579
            updateDataValue('softwareBuild', version) // rbn.common#L580
            break // rbn.common#L581
        default: // rbn.common#L582
            logDebug "zigbee received unknown Basic cluster attribute 0x${descMap.attrId} (value ${descMap.value})" // rbn.common#L583
            break // rbn.common#L584
    } // rbn.common#L585
} // rbn.common#L586

private void standardParsePollControlCluster(final Map descMap) { // rbn.common#L588
    switch (descMap.attrInt as Integer) { // rbn.common#L589
        case 0x0000: logDebug "PollControl cluster: CheckInInterval = ${descMap?.value}" ; break // rbn.common#L590
        case 0x0001: logDebug "PollControl cluster: LongPollInterval = ${descMap?.value}" ; break // rbn.common#L591
        case 0x0002: logDebug "PollControl cluster: ShortPollInterval = ${descMap?.value}" ; break // rbn.common#L592
        case 0x0003: logDebug "PollControl cluster: FastPollTimeout = ${descMap?.value}" ; break // rbn.common#L593
        case 0x0004: logDebug "PollControl cluster: CheckInIntervalMin = ${descMap?.value}" ; break // rbn.common#L594
        case 0x0005: logDebug "PollControl cluster: LongPollIntervalMin = ${descMap?.value}" ; break // rbn.common#L595
        case 0x0006: logDebug "PollControl cluster: FastPollTimeoutMax = ${descMap?.value}" ; break // rbn.common#L596
        default: logDebug "zigbee received unknown PollControl cluster attribute 0x${descMap.attrId} (value ${descMap.value})" ; break // rbn.common#L597
    } // rbn.common#L598
} // rbn.common#L599

public void clearIsDigital()        { state.states['isDigital'] = false } // rbn.common#L601
void switchDebouncingClear() { state.states['debounce']  = false } // rbn.common#L602
void isRefreshRequestClear() { state.states['isRefresh'] = false } // rbn.common#L603

Map myParseDescriptionAsMap(String description) { // rbn.common#L605
    Map descMap = [:] // rbn.common#L606
    try { // rbn.common#L607
        descMap = zigbee.parseDescriptionAsMap(description) // rbn.common#L608
    } // rbn.common#L609
    catch (e1) { // rbn.common#L610
        logWarn "exception ${e1} caught while parseDescriptionAsMap <b>myParseDescriptionAsMap</b> description:  ${description}" // rbn.common#L611

        descMap = [:] // rbn.common#L613
        try { // rbn.common#L614
            descMap += description.replaceAll('\\[|\\]', '').split(',').collectEntries { entry -> // rbn.common#L615
                List<String> pair = entry.split(':') // rbn.common#L616
                [(pair.first().trim()): pair.last().trim()] // rbn.common#L617
            } // rbn.common#L618
        } // rbn.common#L619
        catch (e2) { // rbn.common#L620
            logWarn "exception ${e2} caught while parsing using an alternative method <b>myParseDescriptionAsMap</b> description:  ${description}" // rbn.common#L621
            return [:] // rbn.common#L622
        } // rbn.common#L623
        logDebug "alternative method parsing success: descMap=${descMap}" // rbn.common#L624
    } // rbn.common#L625
    return descMap // rbn.common#L626
} // rbn.common#L627

public String intTo16bitUnsignedHex(int value) { // rbn.common#L629
    String hexStr = zigbee.convertToHexString(value.toInteger(), 4) // rbn.common#L630
    return new String(hexStr.substring(2, 4) + hexStr.substring(0, 2)) // rbn.common#L631
} // rbn.common#L632

public String intTo8bitUnsignedHex(int value) { // rbn.common#L634
    return zigbee.convertToHexString(value.toInteger(), 2) // rbn.common#L635
} // rbn.common#L636

public void aqaraBlackMagic() { // rbn.common#L638
    List<String> cmds = [] // rbn.common#L639
    if (this.respondsTo('customAqaraBlackMagic')) { // rbn.common#L640
        cmds = customAqaraBlackMagic() // rbn.common#L641
    } // rbn.common#L642
    if (cmds != null && !cmds.isEmpty()) { // rbn.common#L643
        logDebug 'sending aqaraBlackMagic()' // rbn.common#L644
        sendZigbeeCommands(cmds) // rbn.common#L645
        return // rbn.common#L646
    } // rbn.common#L647
    logDebug 'aqaraBlackMagic() was SKIPPED' // rbn.common#L648
} // rbn.common#L649

public List<String> initializeDevice() { // rbn.common#L652
    List<String> cmds = [] // rbn.common#L653
    logInfo 'initializeDevice...' // rbn.common#L654
    if (this.respondsTo('customInitializeDevice')) { // rbn.common#L655
        List<String> customCmds = customInitializeDevice() // rbn.common#L656
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // rbn.common#L657
    } // rbn.common#L658
    else { logDebug 'no customInitializeDevice method defined' } // rbn.common#L659
    logDebug "initializeDevice(): cmds=${cmds}" // rbn.common#L660
    return cmds // rbn.common#L661
} // rbn.common#L662

public List<String> configureDevice() { // rbn.common#L665
    List<String> cmds = [] // rbn.common#L666
    logInfo 'configureDevice...' // rbn.common#L667
    if (this.respondsTo('customConfigureDevice')) { // rbn.common#L668
        List<String> customCmds = customConfigureDevice() // rbn.common#L669
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // rbn.common#L670
    } // rbn.common#L671
    else { logDebug 'no customConfigureDevice method defined' } // rbn.common#L672

    logDebug "configureDevice(): cmds=${cmds}" // rbn.common#L674
    return cmds // rbn.common#L675
} // rbn.common#L676

List<String> customHandlers(final List customHandlersList) { // rbn.common#L684
    List<String> cmds = [] // rbn.common#L685
    if (customHandlersList != null && !customHandlersList.isEmpty()) { // rbn.common#L686
        customHandlersList.each { handler -> // rbn.common#L687
            if (this.respondsTo(handler)) { // rbn.common#L688
                List<String> customCmds = this."${handler}"() // rbn.common#L689
                if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // rbn.common#L690
            } // rbn.common#L691
        } // rbn.common#L692
    } // rbn.common#L693
    return cmds // rbn.common#L694
} // rbn.common#L695

public void refresh() { // rbn.common#L697
    logDebug "refresh()... DEVICE_TYPE is ${DEVICE_TYPE} model=${device.getDataValue('model')} manufacturer=${device.getDataValue('manufacturer')}" // rbn.common#L698
    checkDriverVersion(state) // rbn.common#L699
    List<String> cmds = [], customCmds = [] // rbn.common#L700
    if (this.respondsTo('customRefresh')) { // rbn.common#L701
        customCmds = customRefresh() // rbn.common#L702
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } else { logDebug 'no customRefresh method defined' } // rbn.common#L703
    } // rbn.common#L704
    else { // rbn.common#L705
        customCmds = customHandlers(['onOffRefresh', 'groupsRefresh', 'batteryRefresh', 'levelRefresh', 'temperatureRefresh', 'humidityRefresh', 'illuminanceRefresh']) // rbn.common#L706
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } else { logDebug 'no libraries refresh() defined' } // rbn.common#L707
    } // rbn.common#L708
    if (cmds != null && !cmds.isEmpty()) { // rbn.common#L709
        logDebug "refresh() cmds=${cmds}" // rbn.common#L710
        setRefreshRequest() // rbn.common#L711
        sendZigbeeCommands(cmds) // rbn.common#L712
    } // rbn.common#L713
    else { // rbn.common#L714
        logDebug "no refresh() commands defined for device type ${DEVICE_TYPE}" // rbn.common#L715
    } // rbn.common#L716
} // rbn.common#L717

public void setRefreshRequest()   { if (state.states == null) { state.states = [:] } ; state.states['isRefresh'] = true; runInMillis(REFRESH_TIMER, 'clearRefreshRequest', [overwrite: true]) } // rbn.common#L719
public void clearRefreshRequest() { if (state.states == null) { state.states = [:] } ; state.states['isRefresh'] = false } // rbn.common#L720
public void clearInfoEvent()      { sendInfoEvent('clear') } // rbn.common#L721

public void sendInfoEvent(String info=null) { // rbn.common#L723
    if (info == null || info == 'clear') { // rbn.common#L724
        logDebug 'clearing the Status event' // rbn.common#L725
        sendEvent(name: '_status_', value: 'clear', type: 'digital') // rbn.common#L726
    } // rbn.common#L727
    else { // rbn.common#L728
        logInfo "${info}" // rbn.common#L729
        sendEvent(name: '_status_', value: info, type: 'digital') // rbn.common#L730
        runIn(INFO_AUTO_CLEAR_PERIOD, 'clearInfoEvent') // rbn.common#L731
    } // rbn.common#L732
} // rbn.common#L733

public void ping() { // rbn.common#L735
    if (state.lastTx == null ) { state.lastTx = [:] } ; state.lastTx['pingTime'] = new Date().getTime() // rbn.common#L736
    if (state.states == null ) { state.states = [:] } ; state.states['isPing'] = true // rbn.common#L737
    scheduleCommandTimeoutCheck() // rbn.common#L738
    int  pingAttr = (device.getDataValue('manufacturer') == 'SONOFF') ? 0x05 : PING_ATTR_ID // rbn.common#L739
    if (isVirtual()) { runInMillis(10, 'virtualPong') } // rbn.common#L740
    else if (device.getDataValue('manufacturer') == 'Aqara') { // rbn.common#L741
        logDebug 'Aqara device ping...' // rbn.common#L742
        sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, pingAttr, [destEndpoint: 0x01], 0) ) // rbn.common#L743
    } // rbn.common#L744
    else { sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, pingAttr, [:], 0) ) } // rbn.common#L745
    logDebug 'ping...' // rbn.common#L746
} // rbn.common#L747

private void virtualPong() { // rbn.common#L749
    logDebug 'virtualPing: pong!' // rbn.common#L750
    Long now = new Date().getTime() // rbn.common#L751
    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: '0').toInteger() // rbn.common#L752
    if (timeRunning > 0 && timeRunning < MAX_PING_MILISECONDS) { // rbn.common#L753
        state.stats['pingsOK'] = (state.stats['pingsOK'] ?: 0) + 1 // rbn.common#L754
        if (timeRunning < safeToInt((state.stats['pingsMin'] ?: '9999'))) { state.stats['pingsMin'] = timeRunning } // rbn.common#L755
        if (timeRunning > safeToInt((state.stats['pingsMax'] ?: '0')))   { state.stats['pingsMax'] = timeRunning } // rbn.common#L756
        state.stats['pingsAvg'] = approxRollingAverage(safeToDouble(state.stats['pingsAvg']), safeToDouble(timeRunning)) as int // rbn.common#L757
        sendRttEvent() // rbn.common#L758
    } // rbn.common#L759
    else { // rbn.common#L760
        logWarn "unexpected ping timeRunning=${timeRunning} " // rbn.common#L761
    } // rbn.common#L762
    state.states['isPing'] = false // rbn.common#L763
    unscheduleCommandTimeoutCheck(state) // rbn.common#L764
} // rbn.common#L765

public void sendRttEvent( String value=null) { // rbn.common#L767
    Long now = new Date().getTime() // rbn.common#L768
    if (state.lastTx == null ) { state.lastTx = [:] } // rbn.common#L769
    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: now).toInteger() // rbn.common#L770
    String descriptionText = "Round-trip time is ${timeRunning} ms (min=${state.stats['pingsMin']} max=${state.stats['pingsMax']} average=${state.stats['pingsAvg']})" // rbn.common#L771
    if (value == null) { // rbn.common#L772
        logInfo "${descriptionText}" // rbn.common#L773
        sendEvent(name: 'rtt', value: timeRunning, descriptionText: descriptionText, unit: 'ms', type: 'physical') // rbn.common#L774
    } // rbn.common#L775
    else { // rbn.common#L776
        descriptionText = "Round-trip time : ${value}" // rbn.common#L777
        logInfo "${descriptionText}" // rbn.common#L778
        sendEvent(name: 'rtt', value: value, descriptionText: descriptionText, type: 'physical') // rbn.common#L779
    } // rbn.common#L780
} // rbn.common#L781

private String clusterLookup(final Object cluster) { // rbn.common#L783
    if (cluster != null) { // rbn.common#L784
        return zigbee.clusterLookup(cluster.toInteger()) ?: "private cluster 0x${intToHexStr(cluster.toInteger())}" // rbn.common#L785
    } // rbn.common#L786
    logWarn 'cluster is NULL!' // rbn.common#L787
    return 'NULL' // rbn.common#L788
} // rbn.common#L789

private void scheduleCommandTimeoutCheck(int delay = COMMAND_TIMEOUT) { // rbn.common#L791
    if (state.states == null) { state.states = [:] } // rbn.common#L792
    state.states['isTimeoutCheck'] = true // rbn.common#L793
    runIn(delay, 'deviceCommandTimeout') // rbn.common#L794
} // rbn.common#L795

void unscheduleCommandTimeoutCheck(final Map state) { // rbn.common#L798
    if (state.states == null) { state.states = [:] } // rbn.common#L799
    if (state.states['isTimeoutCheck'] == true) { // rbn.common#L800
        state.states['isTimeoutCheck'] = false // rbn.common#L801
        unschedule('deviceCommandTimeout') // rbn.common#L802
    } // rbn.common#L803
} // rbn.common#L804

void deviceCommandTimeout() { // rbn.common#L806
    logWarn 'no response received (sleepy device or offline?)' // rbn.common#L807
    sendRttEvent('timeout') // rbn.common#L808
    state.stats['pingsFail'] = (state.stats['pingsFail'] ?: 0) + 1 // rbn.common#L809
    if (state.health?.isHealthCheck == true) { // rbn.common#L810
        logWarn 'device health check failed!' // rbn.common#L811
        state.health?.checkCtr3 = (state.health?.checkCtr3 ?: 0 ) + 1 // rbn.common#L812
        if (state.health?.checkCtr3 >= PRESENCE_COUNT_THRESHOLD) { // rbn.common#L813
            if ((device.currentValue('healthStatus') ?: 'unknown') != 'offline' ) { // rbn.common#L814
                sendHealthStatusEvent('offline') // rbn.common#L815
            } // rbn.common#L816
        } // rbn.common#L817
        state.health['isHealthCheck'] = false // rbn.common#L818
    } // rbn.common#L819
} // rbn.common#L820

private void scheduleDeviceHealthCheck(final int intervalMins, final int healthMethod) { // rbn.common#L822
    if (healthMethod == 1 || healthMethod == 2)  { // rbn.common#L823
        String cron = getCron( intervalMins * 60 ) // rbn.common#L824
        schedule(cron, 'deviceHealthCheck') // rbn.common#L825
        logDebug "deviceHealthCheck is scheduled every ${intervalMins} minutes" // rbn.common#L826
    } // rbn.common#L827
    else { // rbn.common#L828
        logWarn 'deviceHealthCheck is not scheduled!' // rbn.common#L829
        unschedule('deviceHealthCheck') // rbn.common#L830
    } // rbn.common#L831
} // rbn.common#L832

private void unScheduleDeviceHealthCheck() { // rbn.common#L834
    unschedule('deviceHealthCheck') // rbn.common#L835
    device.deleteCurrentState('healthStatus') // rbn.common#L836
    logWarn 'device health check is disabled!' // rbn.common#L837
} // rbn.common#L838

private void setHealthStatusOnline(Map state) { // rbn.common#L841
    if (state.health == null) { state.health = [:] } // rbn.common#L842
    state.health['checkCtr3']  = 0 // rbn.common#L843
    if (!((device.currentValue('healthStatus') ?: 'unknown') in ['online'])) { // rbn.common#L844
        sendHealthStatusEvent('online') // rbn.common#L845
        logInfo 'is now online!' // rbn.common#L846
    } // rbn.common#L847
} // rbn.common#L848

private void deviceHealthCheck() { // rbn.common#L850
    checkDriverVersion(state) // rbn.common#L851
    if (state.health == null) { state.health = [:] } // rbn.common#L852
    int ctr = state.health['checkCtr3'] ?: 0 // rbn.common#L853
    if (ctr  >= PRESENCE_COUNT_THRESHOLD) { // rbn.common#L854
        if ((device.currentValue('healthStatus') ?: 'unknown') != 'offline' ) { // rbn.common#L855
            logWarn 'not present!' // rbn.common#L856
            sendHealthStatusEvent('offline') // rbn.common#L857
        } // rbn.common#L858
    } // rbn.common#L859
    else { // rbn.common#L860
        logDebug "deviceHealthCheck - online (notPresentCounter=${(ctr + 1)})" // rbn.common#L861
    } // rbn.common#L862
    state.health['checkCtr3'] = ctr + 1 // rbn.common#L863

    if (settings?.healthCheckMethod as int == 2) { // rbn.common#L865
        state.health['isHealthCheck'] = true // rbn.common#L866
        ping() // rbn.common#L867
    } // rbn.common#L868
} // rbn.common#L869

private void sendHealthStatusEvent(final String value) { // rbn.common#L871
    String descriptionText = "healthStatus changed to ${value}" // rbn.common#L872
    sendEvent(name: 'healthStatus', value: value, descriptionText: descriptionText, isStateChange: true, type: 'digital') // rbn.common#L873
    if (value == 'online') { // rbn.common#L874
        logInfo "${descriptionText}" // rbn.common#L875
    } // rbn.common#L876
    else { // rbn.common#L877
        if (settings?.txtEnable) { log.warn "${device.displayName} <b>${descriptionText}</b>" } // rbn.common#L878
    } // rbn.common#L879
} // rbn.common#L880

void updated() { // rbn.common#L883
    logInfo 'updated()...' // rbn.common#L884
    checkDriverVersion(state) // rbn.common#L885
    logInfo"driver version ${driverVersionAndTimeStamp()}" // rbn.common#L886
    unschedule() // rbn.common#L887

    if (settings.logEnable) { // rbn.common#L889
        logTrace(settings.toString()) // rbn.common#L890
        runIn(86400, 'logsOff') // rbn.common#L891
    } // rbn.common#L892
    if (settings.traceEnable) { // rbn.common#L893
        logTrace(settings.toString()) // rbn.common#L894
        runIn(1800, 'traceOff') // rbn.common#L895
    } // rbn.common#L896

    final int healthMethod = (settings.healthCheckMethod as Integer) ?: 0 // rbn.common#L898
    if (healthMethod == 1 || healthMethod == 2) { // rbn.common#L899

        final int interval = (settings.healthCheckInterval as Integer) ?: 0 // rbn.common#L901
        if (interval > 0) { // rbn.common#L902

            log.info "scheduling health check every ${interval} minutes by ${HealthcheckMethodOpts.options[healthMethod]} method" // rbn.common#L904
            scheduleDeviceHealthCheck(interval, healthMethod) // rbn.common#L905
        } // rbn.common#L906
    } // rbn.common#L907
    else { // rbn.common#L908
        unScheduleDeviceHealthCheck() // rbn.common#L909
        log.info 'Health Check is disabled!' // rbn.common#L910
    } // rbn.common#L911
    if (this.respondsTo('customUpdated')) { // rbn.common#L912
        customUpdated() // rbn.common#L913
    } // rbn.common#L914

    sendInfoEvent('updated') // rbn.common#L916
} // rbn.common#L917

private void logsOff() { // rbn.common#L919
    logInfo 'debug logging disabled...' // rbn.common#L920
    device.updateSetting('logEnable', [value: 'false', type: 'bool']) // rbn.common#L921
} // rbn.common#L922
private void traceOff() { // rbn.common#L923
    logInfo 'trace logging disabled...' // rbn.common#L924
    device.updateSetting('traceEnable', [value: 'false', type: 'bool']) // rbn.common#L925
} // rbn.common#L926

public void deviceUtilities(String command = null) { // rbn.common#L929
    logInfo "deviceUtilities(${command})..." // rbn.common#L930
    if (command == null || !(command in (ConfigureOpts.keySet() as List))) { // rbn.common#L931
        configureHelp(command) // rbn.common#L932
        return // rbn.common#L933
    } // rbn.common#L934

    String func // rbn.common#L936
    try { // rbn.common#L937
        func = ConfigureOpts[command]?.function // rbn.common#L938
        "$func"() // rbn.common#L939
    } // rbn.common#L940
    catch (e) { // rbn.common#L941
        logWarn "Exception ${e} caught while processing <b>$func</b>(<b>$value</b>)" // rbn.common#L942
        return // rbn.common#L943
    } // rbn.common#L944
    logInfo "executed '${func}'" // rbn.common#L945
} // rbn.common#L946

void configureHelp(final String val = null) { // rbn.common#L949
    logInfo "select one of the commands from the list: ${ConfigureOpts.keySet() as List}" // rbn.common#L950
    sendInfoEvent('Please select a command from the drop-down list') // rbn.common#L951
} // rbn.common#L952

public void loadAllDefaults() { // rbn.common#L954
    logDebug 'loadAllDefaults() !!!' // rbn.common#L955
    deleteAllSettings() // rbn.common#L956
    deleteAllCurrentStates() // rbn.common#L957
    deleteAllScheduledJobs() // rbn.common#L958
    deleteAllStates() // rbn.common#L959
    deleteAllChildDevices() // rbn.common#L960

    initialize() // rbn.common#L962
    configureNow() // rbn.common#L963
    updated() // rbn.common#L964
    sendInfoEvent('All Defaults Loaded! F5 to refresh') // rbn.common#L965
} // rbn.common#L966

private void configureNow() { // rbn.common#L968
    configure() // rbn.common#L969
} // rbn.common#L970

void configure() { // rbn.common#L977
    List<String> cmds = [] // rbn.common#L978
    if (state.stats == null) { state.stats = [:] } ; state.stats.cfgCtr = (state.stats.cfgCtr ?: 0) + 1 // rbn.common#L979
    logInfo "configure()... cfgCtr=${state.stats.cfgCtr}" // rbn.common#L980
    logDebug "configure(): settings: $settings" // rbn.common#L981
    aqaraBlackMagic() // rbn.common#L982
    List<String> initCmds = initializeDevice() // rbn.common#L983
    if (initCmds != null && !initCmds.isEmpty()) { cmds += initCmds } // rbn.common#L984
    List<String> cfgCmds = configureDevice() // rbn.common#L985
    if (cfgCmds != null && !cfgCmds.isEmpty()) { cmds += cfgCmds } // rbn.common#L986
    if (cmds != null && !cmds.isEmpty()) { // rbn.common#L987
        sendZigbeeCommands(cmds) // rbn.common#L988
        logDebug "configure(): sent cmds = ${cmds}" // rbn.common#L989
        sendInfoEvent('sent device configuration') // rbn.common#L990
    } // rbn.common#L991
    else { // rbn.common#L992
        logDebug "configure(): no commands defined for device type ${DEVICE_TYPE}" // rbn.common#L993
    } // rbn.common#L994
} // rbn.common#L995

void installed() { // rbn.common#L998
    if (state.stats == null) { state.stats = [:] } ; state.stats.instCtr = (state.stats.instCtr ?: 0) + 1 // rbn.common#L999
    logInfo "installed()... instCtr=${state.stats.instCtr}" // rbn.common#L1000

    sendEvent(name: 'healthStatus', value: 'unknown', descriptionText: 'device was installed', type: 'digital') // rbn.common#L1002
    sendEvent(name: 'powerSource',  value: 'unknown', descriptionText: 'device was installed', type: 'digital') // rbn.common#L1003
    sendInfoEvent('installed') // rbn.common#L1004
    runIn(3, 'updated') // rbn.common#L1005
    runIn(5, 'queryPowerSource') // rbn.common#L1006
} // rbn.common#L1007

private void queryPowerSource() { // rbn.common#L1009
    sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, 0x0007, [:], 0)) // rbn.common#L1010
} // rbn.common#L1011

private void initialize() { // rbn.common#L1014
    if (state.stats == null) { state.stats = [:] } ; state.stats.initCtr = (state.stats.initCtr ?: 0) + 1 // rbn.common#L1015
    logDebug "initialize()... initCtr=${state.stats.initCtr}" // rbn.common#L1016
    if (device.getDataValue('powerSource') == null) { // rbn.common#L1017
        logDebug "initializing device powerSource 'unknown'" // rbn.common#L1018
        sendEvent(name: 'powerSource', value: 'unknown', type: 'digital') // rbn.common#L1019
    } // rbn.common#L1020
    if (this.respondsTo('customInitialize')) { customInitialize() } // rbn.common#L1021
    initializeVars(fullInit = true) // rbn.common#L1022
    updateAqaraVersion() // rbn.common#L1023
} // rbn.common#L1024

static Integer safeToInt(Object val, Integer defaultVal=0) { // rbn.common#L1032
    return "${val}"?.isInteger() ? "${val}".toInteger() : defaultVal // rbn.common#L1033
} // rbn.common#L1034

static Double safeToDouble(Object val, Double defaultVal=0.0) { // rbn.common#L1036
    return "${val}"?.isDouble() ? "${val}".toDouble() : defaultVal // rbn.common#L1037
} // rbn.common#L1038

static BigDecimal safeToBigDecimal(Object val, BigDecimal defaultVal=0.0) { // rbn.common#L1040
    return "${val}"?.isBigDecimal() ? "${val}".toBigDecimal() : defaultVal // rbn.common#L1041
} // rbn.common#L1042

public void sendZigbeeCommands(List<String> cmd) { // rbn.common#L1044
    if (cmd == null || cmd.isEmpty()) { // rbn.common#L1045
        logWarn "sendZigbeeCommands: list is empty! cmd=${cmd}" // rbn.common#L1046
        return // rbn.common#L1047
    } // rbn.common#L1048
    hubitat.device.HubMultiAction allActions = new hubitat.device.HubMultiAction() // rbn.common#L1049
    cmd.each { // rbn.common#L1050
        if (it == null || it.isEmpty() || it == 'null') { // rbn.common#L1051
            logWarn "sendZigbeeCommands it: no commands to send! it=${it} (cmd=${cmd})" // rbn.common#L1052
            return // rbn.common#L1053
        } // rbn.common#L1054
        allActions.add(new hubitat.device.HubAction(it, hubitat.device.Protocol.ZIGBEE)) // rbn.common#L1055
        if (state.stats != null) { state.stats['txCtr'] = (state.stats['txCtr'] ?: 0) + 1 } else { state.stats = [:] } // rbn.common#L1056
    } // rbn.common#L1057
    if (state.lastTx != null) { state.lastTx['cmdTime'] = now() } else { state.lastTx = [:] } // rbn.common#L1058
    sendHubCommand(allActions) // rbn.common#L1059
    logDebug "sendZigbeeCommands: sent cmd=${cmd}" // rbn.common#L1060
} // rbn.common#L1061

private String driverVersionAndTimeStamp() { version() + ' ' + timeStamp() + ((_DEBUG) ? ' (debug version!) ' : ' ') + "(${device.getDataValue('model')} ${device.getDataValue('manufacturer')}) (${getModel()} ${location.hub.firmwareVersionString})" } // rbn.common#L1063

private String getDeviceInfo() { // rbn.common#L1065
    return "model=${device.getDataValue('model')} manufacturer=${device.getDataValue('manufacturer')} destinationEP=${state.destinationEP ?: UNKNOWN} <b>deviceProfile=${state.deviceProfile ?: UNKNOWN}</b>" // rbn.common#L1066
} // rbn.common#L1067

public String getDestinationEP() { // rbn.common#L1069
    return state.destinationEP ?: device.endpointId ?: '01' // rbn.common#L1070
} // rbn.common#L1071

public void checkDriverVersion(final Map stateCopy) { // rbn.common#L1074
    if (stateCopy.driverVersion == null || driverVersionAndTimeStamp() != stateCopy.driverVersion) { // rbn.common#L1075
        logDebug "checkDriverVersion: updating the settings from the current driver version ${stateCopy.driverVersion} to the new version ${driverVersionAndTimeStamp()}" // rbn.common#L1076
        sendInfoEvent("Updated to version ${driverVersionAndTimeStamp()} from version ${stateCopy.driverVersion ?: 'unknown'}") // rbn.common#L1077
        state.driverVersion = driverVersionAndTimeStamp() // rbn.common#L1078
        initializeVars(false) // rbn.common#L1079
        updateAqaraVersion() // rbn.common#L1080
        if (this.respondsTo('customcheckDriverVersion')) { customcheckDriverVersion(stateCopy) } // rbn.common#L1081
    } // rbn.common#L1082
    if (state.states == null) { state.states = [:] } ; if (state.lastRx == null) { state.lastRx = [:] } ; if (state.lastTx == null) { state.lastTx = [:] } ; if (state.stats  == null) { state.stats =  [:] } // rbn.common#L1083
} // rbn.common#L1084

String getModel() { // rbn.common#L1087
    try { // rbn.common#L1088

        String model = getHubVersion() // rbn.common#L1090
    } catch (ignore) { // rbn.common#L1091
        try { // rbn.common#L1092
            httpGet("http://${location.hub.localIP}:8080/api/hubitat.xml") { res -> // rbn.common#L1093
                model = res.data.device.modelName // rbn.common#L1094
                return model // rbn.common#L1095
            } // rbn.common#L1096
        } catch (ignore_again) { // rbn.common#L1097
            return '' // rbn.common#L1098
        } // rbn.common#L1099
    } // rbn.common#L1100
} // rbn.common#L1101

boolean isCompatible(Integer minLevel) { // rbn.common#L1104
    String model = getModel() // rbn.common#L1105
    String[] tokens = model.split('-') // rbn.common#L1106
    String revision = tokens.last() // rbn.common#L1107
    return (Integer.parseInt(revision) >= minLevel) // rbn.common#L1108
} // rbn.common#L1109

void deleteAllStatesAndJobs() { // rbn.common#L1111
    state.clear() // rbn.common#L1112
    unschedule() // rbn.common#L1113
    device.deleteCurrentState('*') // rbn.common#L1114
    device.deleteCurrentState('') // rbn.common#L1115

    log.info "${device.displayName} jobs and states cleared. HE hub is ${getHubVersion()}, version is ${location.hub.firmwareVersionString}" // rbn.common#L1117
} // rbn.common#L1118

void resetStatistics() { // rbn.common#L1120
    runIn(1, 'resetStats') // rbn.common#L1121
    sendInfoEvent('Statistics are reset. Refresh the web page') // rbn.common#L1122
} // rbn.common#L1123

void resetStats() { // rbn.common#L1126
    logDebug 'resetStats...' // rbn.common#L1127
    state.stats = [:] ; state.states = [:] ; state.lastRx = [:] ; state.lastTx = [:] ; state.health = [:] // rbn.common#L1128
    if (this.respondsTo('groupsLibVersion')) { state.zigbeeGroups = [:] } // rbn.common#L1129
    state.stats.rxCtr = 0 ; state.stats.txCtr = 0 // rbn.common#L1130
    state.states['isDigital'] = false ; state.states['isRefresh'] = false ; state.states['isPing'] = false // rbn.common#L1131
    state.health['offlineCtr'] = 0 ; state.health['checkCtr3'] = 0 // rbn.common#L1132
    if (this.respondsTo('customResetStats')) { customResetStats() } // rbn.common#L1133
    logInfo 'statistics reset!' // rbn.common#L1134
} // rbn.common#L1135

void initializeVars( boolean fullInit = false ) { // rbn.common#L1137
    logDebug "InitializeVars()... fullInit = ${fullInit}" // rbn.common#L1138
    if (fullInit == true ) { // rbn.common#L1139
        state.clear() // rbn.common#L1140
        unschedule() // rbn.common#L1141
        resetStats() // rbn.common#L1142
        if (this.respondsTo('setDeviceNameAndProfile')) { setDeviceNameAndProfile() } // rbn.common#L1143

        logInfo 'all states and scheduled jobs cleared!' // rbn.common#L1145
        state.driverVersion = driverVersionAndTimeStamp() // rbn.common#L1146
        logInfo "DEVICE_TYPE = ${DEVICE_TYPE}" // rbn.common#L1147
        state.deviceType = DEVICE_TYPE // rbn.common#L1148
        sendInfoEvent('Initialized') // rbn.common#L1149
    } // rbn.common#L1150

    if (state.stats == null)  { state.stats  = [:] } // rbn.common#L1152
    if (state.states == null) { state.states = [:] } // rbn.common#L1153
    if (state.lastRx == null) { state.lastRx = [:] } // rbn.common#L1154
    if (state.lastTx == null) { state.lastTx = [:] } // rbn.common#L1155
    if (state.health == null) { state.health = [:] } // rbn.common#L1156

    if (fullInit || settings?.txtEnable == null) { device.updateSetting('txtEnable', true) } // rbn.common#L1158
    if (fullInit || settings?.logEnable == null) { device.updateSetting('logEnable', DEFAULT_DEBUG_LOGGING ?: false) } // rbn.common#L1159
    if (fullInit || settings?.traceEnable == null) { device.updateSetting('traceEnable', false) } // rbn.common#L1160
    if (fullInit || settings?.advancedOptions == null) { device.updateSetting('advancedOptions', [value:false, type:'bool']) } // rbn.common#L1161
    if (fullInit || settings?.healthCheckMethod == null) { device.updateSetting('healthCheckMethod', [value: HealthcheckMethodOpts.defaultValue.toString(), type: 'enum']) } // rbn.common#L1162
    if (fullInit || settings?.healthCheckInterval == null) { device.updateSetting('healthCheckInterval', [value: HealthcheckIntervalOpts.defaultValue.toString(), type: 'enum']) } // rbn.common#L1163
    if (fullInit || settings?.ignoreDuplicatedZigbeeMessages == null) { device.updateSetting('ignoreDuplicatedZigbeeMessages', false) } // rbn.common#L1164
    if (fullInit || settings?.voltageToPercent == null) { device.updateSetting('voltageToPercent', false) } // rbn.common#L1165

    if (device.currentValue('healthStatus') == null) { sendHealthStatusEvent('unknown') } // rbn.common#L1167

    executeCustomHandler('batteryInitializeVars', fullInit) // rbn.common#L1170
    executeCustomHandler('motionInitializeVars', fullInit) // rbn.common#L1171
    executeCustomHandler('groupsInitializeVars', fullInit) // rbn.common#L1172
    executeCustomHandler('illuminanceInitializeVars', fullInit) // rbn.common#L1173
    executeCustomHandler('onOfInitializeVars', fullInit) // rbn.common#L1174
    executeCustomHandler('energyInitializeVars', fullInit) // rbn.common#L1175

    executeCustomHandler('deviceProfileInitializeVars', fullInit) // rbn.common#L1177
    executeCustomHandler('initEventsDeviceProfile', fullInit) // rbn.common#L1178

    executeCustomHandler('customInitializeVars', fullInit) // rbn.common#L1181
    executeCustomHandler('customCreateChildDevices', fullInit) // rbn.common#L1182
    executeCustomHandler('customInitEvents', fullInit) // rbn.common#L1183

    final String mm = device.getDataValue('model') // rbn.common#L1185
    if (mm != null) { logTrace " model = ${mm}" } // rbn.common#L1186
    else { logWarn ' Model not found, please re-pair the device!' } // rbn.common#L1187
    final String ep = device.getEndpointId() // rbn.common#L1188
    if ( ep  != null) { // rbn.common#L1189

        logTrace " destinationEP = ${ep}" // rbn.common#L1191
    } // rbn.common#L1192
    else { // rbn.common#L1193
        logWarn ' Destination End Point not found, please re-pair the device!' // rbn.common#L1194

    } // rbn.common#L1196
} // rbn.common#L1197

void setDestinationEP() { // rbn.common#L1200
    String ep = device.getEndpointId() // rbn.common#L1201
    if (ep != null && ep != 'F2') { state.destinationEP = ep ; logDebug "setDestinationEP() destinationEP = ${state.destinationEP}" } // rbn.common#L1202
    else { logWarn "setDestinationEP() Destination End Point not found or invalid(${ep}), activating the F2 bug patch!" ; state.destinationEP = '01' } // rbn.common#L1203
} // rbn.common#L1204

void logDebug(final String msg) { if (settings?.logEnable)   { log.debug "${device.displayName} " + msg } } // rbn.common#L1206
void logInfo(final String msg)  { if (settings?.txtEnable)   { log.info  "${device.displayName} " + msg } } // rbn.common#L1207
void logWarn(final String msg)  { if (settings?.logEnable)   { log.warn  "${device.displayName} " + msg } } // rbn.common#L1208
void logTrace(final String msg) { if (settings?.traceEnable) { log.trace "${device.displayName} " + msg } } // rbn.common#L1209
void logError(final String msg) { if (settings?.txtEnable)   { log.error "${device.displayName} " + msg } } // rbn.common#L1210

void getAllProperties() { // rbn.common#L1213
    log.trace 'Properties:' ; device.properties.each { it -> log.debug it } // rbn.common#L1214
    log.trace 'Settings:' ;  settings.each { it -> log.debug "${it.key} =  ${it.value}" } // rbn.common#L1215
} // rbn.common#L1216

void deleteAllSettings() { // rbn.common#L1219
    String preferencesDeleted = '' // rbn.common#L1220
    settings.each { it -> preferencesDeleted += "${it.key} (${it.value}), " ; device.removeSetting("${it.key}") } // rbn.common#L1221
    logDebug "Deleted settings: ${preferencesDeleted}" // rbn.common#L1222
    logInfo  'All settings (preferences) DELETED' // rbn.common#L1223
} // rbn.common#L1224

void deleteAllCurrentStates() { // rbn.common#L1227
    String attributesDeleted = '' // rbn.common#L1228
    device.properties.supportedAttributes.each { it -> attributesDeleted += "${it}, " ; device.deleteCurrentState("$it") } // rbn.common#L1229
    logDebug "Deleted attributes: ${attributesDeleted}" ; logInfo 'All current states (attributes) DELETED' // rbn.common#L1230
} // rbn.common#L1231

void deleteAllStates() { // rbn.common#L1234
    String stateDeleted = '' // rbn.common#L1235
    state.each { it -> stateDeleted += "${it.key}, " } // rbn.common#L1236
    state.clear() // rbn.common#L1237
    logDebug "Deleted states: ${stateDeleted}" ; logInfo 'All States DELETED' // rbn.common#L1238
} // rbn.common#L1239

void deleteAllScheduledJobs() { // rbn.common#L1241
    unschedule() ; logInfo 'All scheduled jobs DELETED' // rbn.common#L1242
} // rbn.common#L1243

void deleteAllChildDevices() { // rbn.common#L1245
    getChildDevices().each { child -> log.info "${device.displayName} Deleting ${child.deviceNetworkId}" ; deleteChildDevice(child.deviceNetworkId) } // rbn.common#L1246
    sendInfoEvent 'All child devices DELETED' // rbn.common#L1247
} // rbn.common#L1248

void testParse(String par) { // rbn.common#L1250

    log.trace '------------------------------------------------------' // rbn.common#L1252
    log.warn "testParse - <b>START</b> (${par})" // rbn.common#L1253
    parse(par) // rbn.common#L1254
    log.warn "testParse -   <b>END</b> (${par})" // rbn.common#L1255
    log.trace '------------------------------------------------------' // rbn.common#L1256
} // rbn.common#L1257

Object testJob() { // rbn.common#L1259
    log.warn 'test job executed' // rbn.common#L1260
} // rbn.common#L1261

String getCron(int timeInSeconds) { // rbn.common#L1267

    final Random rnd = new Random() // rbn.common#L1270
    int minutes = (timeInSeconds / 60 ) as int // rbn.common#L1271
    int  hours = (minutes / 60 ) as int // rbn.common#L1272
    if (hours > 23) { hours = 23 } // rbn.common#L1273
    String cron // rbn.common#L1274
    if (timeInSeconds < 60) { cron = "*/$timeInSeconds * * * * ? *" } // rbn.common#L1275
    else { // rbn.common#L1276
        if (minutes < 60) {   cron = "${rnd.nextInt(59)} ${rnd.nextInt(9)}/$minutes * ? * *" } // rbn.common#L1277
        else {                cron = "${rnd.nextInt(59)} ${rnd.nextInt(59)} */$hours ? * *"  } // rbn.common#L1278
    } // rbn.common#L1279
    return cron // rbn.common#L1280
} // rbn.common#L1281

String formatUptime() { // rbn.common#L1284
    return formatTime(location.hub.uptime) // rbn.common#L1285
} // rbn.common#L1286

String formatTime(int timeInSeconds) { // rbn.common#L1288
    if (timeInSeconds == null) { return UNKNOWN } // rbn.common#L1289
    int days = (timeInSeconds / 86400).toInteger() // rbn.common#L1290
    int hours = ((timeInSeconds % 86400) / 3600).toInteger() // rbn.common#L1291
    int minutes = ((timeInSeconds % 3600) / 60).toInteger() // rbn.common#L1292
    int seconds = (timeInSeconds % 60).toInteger() // rbn.common#L1293
    return "${days}d ${hours}h ${minutes}m ${seconds}s" // rbn.common#L1294
} // rbn.common#L1295

boolean isAqara() { return device.getDataValue('model')?.startsWith('lumi') ?: false } // rbn.common#L1297

void updateAqaraVersion() { // rbn.common#L1299
    if (!isAqara()) { logTrace 'not Aqara' ; return } // rbn.common#L1300
    String application = device.getDataValue('application') // rbn.common#L1301
    if (application != null) { // rbn.common#L1302
        String str = '0.0.0_' + String.format('%04d', zigbee.convertHexToInt(application.take(2))) // rbn.common#L1303
        if (device.getDataValue('aqaraVersion') != str) { // rbn.common#L1304
            device.updateDataValue('aqaraVersion', str) // rbn.common#L1305
            logInfo "aqaraVersion set to $str" // rbn.common#L1306
        } // rbn.common#L1307
    } // rbn.common#L1308
} // rbn.common#L1309

String unix2formattedDate(Long unixTime) { // rbn.common#L1311
    try { // rbn.common#L1312
        if (unixTime == null) { return null } // rbn.common#L1313

        Date date = new Date(unixTime.toLong()) // rbn.common#L1315
        return date.format('yyyy-MM-dd HH:mm:ss.SSS', location.timeZone) // rbn.common#L1316
    } catch (e) { // rbn.common#L1317
        logDebug "Error formatting date: ${e.message}. Returning current time instead." // rbn.common#L1318
        return new Date().format('yyyy-MM-dd HH:mm:ss.SSS', location.timeZone) // rbn.common#L1319
    } // rbn.common#L1320
} // rbn.common#L1321

Long formattedDate2unix(String formattedDate) { // rbn.common#L1323
    try { // rbn.common#L1324
        if (formattedDate == null) { return null } // rbn.common#L1325
        Date date = Date.parse('yyyy-MM-dd HH:mm:ss.SSS', formattedDate) // rbn.common#L1326
        return date.getTime() // rbn.common#L1327
    } catch (e) { // rbn.common#L1328
        logDebug "Error parsing formatted date: ${formattedDate}. Returning current time instead." // rbn.common#L1329
        return now() // rbn.common#L1330
    } // rbn.common#L1331
} // rbn.common#L1332

static String timeToHMS(final int time) { // rbn.common#L1334
    int hours = (time / 3600) as int // rbn.common#L1335
    int minutes = ((time % 3600) / 60) as int // rbn.common#L1336
    int seconds = time % 60 // rbn.common#L1337
    return "${hours}h ${minutes}m ${seconds}s" // rbn.common#L1338
} // rbn.common#L1339
// ~~~~~ end include rbn.common ~~~~~

// ~~~~~ start include rbn.switch ~~~~~
library( // rbn.switch#L2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee OnOff Cluster Library', name: 'switch', namespace: 'rbn', // rbn.switch#L3
    importUrl: '', documentationLink: '', // rbn.switch#L4
    version: '3.2.4' // rbn.switch#L5
) // rbn.switch#L6
/*
 *  Zigbee OnOff Cluster Library
 *
 *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License. You may obtain a copy of the License at:
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 *  for the specific language governing permissions and limitations under the License.
 *
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/onOffLib.groovy) at commit 0bf47407.
 *  Modified for the rbn namespace: Tuya 0xEF00 switch branch removed from on()/off(); identity.
 *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/switch.groovy#L22-L28
*/

static String onOffLibVersion()   { '3.2.4' } // rbn.switch#L31
static String onOffLibStamp() { '2026/08/23 4:27 PM' } // rbn.switch#L32

@Field static final Boolean _THREE_STATE = true // rbn.switch#L34

metadata { // rbn.switch#L36
    capability 'Actuator' // rbn.switch#L37
    capability 'Switch' // rbn.switch#L38
    if (_THREE_STATE == true) { // rbn.switch#L39
        attribute 'switch', 'enum', SwitchThreeStateOpts.options.values() as List<String> // rbn.switch#L40
    } // rbn.switch#L41

    preferences { // rbn.switch#L43
        if (settings?.advancedOptions == true && device != null && !(DEVICE_TYPE in ['Device', 'Thermostat'])) { // rbn.switch#L44
            input(name: 'ignoreDuplicated', type: 'bool', title: '<b>Ignore Duplicated Switch Events</b>', description: 'Some switches and plugs send periodically the switch status as a heart-beet ', defaultValue: true) // rbn.switch#L45
            input(name: 'alwaysOn', type: 'bool', title: '<b>Always On</b>', description: 'Disable switching off plugs and switches that must stay always On', defaultValue: false) // rbn.switch#L46
            if (_THREE_STATE == true) { // rbn.switch#L47
                input name: 'threeStateEnable', type: 'bool', title: '<b>Enable three-states events</b>', description: 'Experimental multi-state switch events', defaultValue: false // rbn.switch#L48
            } // rbn.switch#L49
        } // rbn.switch#L50
    } // rbn.switch#L51
} // rbn.switch#L52

@Field static final Map SwitchThreeStateOpts = [ // rbn.switch#L54
    defaultValue: 0, options: [0: 'off', 1: 'on', 2: 'switching_off', 3: 'switching_on', 4: 'switch_failure'] // rbn.switch#L55
] // rbn.switch#L56

@Field static final Map powerOnBehaviourOptions = [ // rbn.switch#L58
    '0': 'switch off', '1': 'switch on', '2': 'switch last state' // rbn.switch#L59
] // rbn.switch#L60

@Field static final Map switchTypeOptions = [ // rbn.switch#L62
    '0': 'toggle', '1': 'state', '2': 'momentary' // rbn.switch#L63
] // rbn.switch#L64

private boolean isCircuitBreaker()      { device.getDataValue('manufacturer') in ['_TZ3000_ky0fq4ho'] } // rbn.switch#L66

void standardParseOnOffCluster(final Map descMap) { // rbn.switch#L73

    if (descMap.attrId == '0000') { // rbn.switch#L79
        if (descMap.value == null || descMap.value == 'FFFF') { logDebug "parseOnOffCluster: invalid value: ${descMap.value}"; return } // rbn.switch#L80
        int rawValue = hexStrToUnsignedInt(descMap.value) // rbn.switch#L81
        sendSwitchEvent(rawValue) // rbn.switch#L82
    } // rbn.switch#L83
    else if (descMap.attrId in ['4000', '4001', '4002', '4004', '8000', '8001', '8002', '8003']) { // rbn.switch#L84
        parseOnOffAttributes(descMap) // rbn.switch#L85
    } // rbn.switch#L86
    else { // rbn.switch#L87
        if (descMap.attrId != null) { logWarn "standardParseOnOffCluster: unprocessed attrId ${descMap.attrId}"  } // rbn.switch#L88
        else { logDebug "standardParseOnOffCluster: skipped processing OnOff cluster (attrId is ${descMap.attrId})" } // rbn.switch#L89
    } // rbn.switch#L90
} // rbn.switch#L91

void toggleX() { // rbn.switch#L93
    String descriptionText = 'central button switch is ' // rbn.switch#L94
    String state = '' // rbn.switch#L95
    if ((device.currentState('switch')?.value ?: 'n/a') == 'off') { // rbn.switch#L96
        state = 'on' // rbn.switch#L97
    } // rbn.switch#L98
    else { // rbn.switch#L99
        state = 'off' // rbn.switch#L100
    } // rbn.switch#L101
    descriptionText += state // rbn.switch#L102
    sendEvent(name: 'switch', value: state, descriptionText: descriptionText, type: 'physical', isStateChange: true) // rbn.switch#L103
    logInfo "${descriptionText}" // rbn.switch#L104
} // rbn.switch#L105

void off() { // rbn.switch#L107
    if (this.respondsTo('customOff')) { customOff() ; return  } // rbn.switch#L108
    if ((settings?.alwaysOn ?: false) == true) { logWarn "AlwaysOn option for ${device.displayName} is enabled , the command to switch it OFF is ignored!" ; return } // rbn.switch#L109
    List<String> cmds = (settings?.inverceSwitch == null || settings?.inverceSwitch == false) ?  zigbee.off()  : zigbee.on() // rbn.switch#L110

    String currentState = device.currentState('switch')?.value ?: 'n/a' // rbn.switch#L112
    logDebug "off() currentState=${currentState}" // rbn.switch#L113
    if (_THREE_STATE == true && settings?.threeStateEnable == true) { // rbn.switch#L114
        if (currentState == 'off') { // rbn.switch#L115
            runIn(1, 'refresh',  [overwrite: true]) // rbn.switch#L116
        } // rbn.switch#L117
        String value = SwitchThreeStateOpts.options[2] // rbn.switch#L118
        String descriptionText = "${value}" // rbn.switch#L119
        if (logEnable) { descriptionText += ' (2)' } // rbn.switch#L120
        sendEvent(name: 'switch', value: value, descriptionText: descriptionText, type: 'digital', isStateChange: true) // rbn.switch#L121
        logInfo "${descriptionText}" // rbn.switch#L122
    } // rbn.switch#L123
    state.states['isDigital'] = true // rbn.switch#L124
    runInMillis(DIGITAL_TIMER, clearIsDigital, [overwrite: true]) // rbn.switch#L125
    sendZigbeeCommands(cmds) // rbn.switch#L126
} // rbn.switch#L127

void on() { // rbn.switch#L129
    if (this.respondsTo('customOn')) { customOn() ; return } // rbn.switch#L130
    List<String> cmds = (settings?.inverceSwitch == null || settings?.inverceSwitch == false) ?  zigbee.on()  : zigbee.off() // rbn.switch#L131
    String currentState = device.currentState('switch')?.value ?: 'n/a' // rbn.switch#L132
    logDebug "on() currentState=${currentState}" // rbn.switch#L133
    if (_THREE_STATE == true && settings?.threeStateEnable == true) { // rbn.switch#L134
        if ((device.currentState('switch')?.value ?: 'n/a') == 'on') { // rbn.switch#L135
            runIn(1, 'refresh',  [overwrite: true]) // rbn.switch#L136
        } // rbn.switch#L137
        String value = SwitchThreeStateOpts.options[3] // rbn.switch#L138
        String descriptionText = "${value}" // rbn.switch#L139
        if (logEnable) { descriptionText += ' (2)' } // rbn.switch#L140
        sendEvent(name: 'switch', value: value, descriptionText: descriptionText, type: 'digital', isStateChange: true) // rbn.switch#L141
        logInfo "${descriptionText}" // rbn.switch#L142
    } // rbn.switch#L143
    state.states['isDigital'] = true // rbn.switch#L144
    runInMillis(DIGITAL_TIMER, clearIsDigital, [overwrite: true]) // rbn.switch#L145
    sendZigbeeCommands(cmds) // rbn.switch#L146
} // rbn.switch#L147

void sendSwitchEvent(int switchValuePar) { // rbn.switch#L149
    int switchValue = safeToInt(switchValuePar) // rbn.switch#L150
    if (settings?.inverceSwitch != null && settings?.inverceSwitch == true) { // rbn.switch#L151
        switchValue = (switchValue == 0x00) ? 0x01 : 0x00 // rbn.switch#L152
    } // rbn.switch#L153
    String value = (switchValue == null) ? 'unknown' : (switchValue == 0x00) ? 'off' : (switchValue == 0x01) ? 'on' : 'unknown' // rbn.switch#L154
    Map map = [:] // rbn.switch#L155
    boolean isRefresh = state.states['isRefresh'] ?: false // rbn.switch#L156
    boolean debounce = state.states['debounce'] ?: false // rbn.switch#L157
    String lastSwitch = state.states['lastSwitch'] ?: 'unknown' // rbn.switch#L158
    if (value == lastSwitch && (debounce || (settings.ignoreDuplicated ?: false)) && !isRefresh) { // rbn.switch#L159
        logDebug "Ignored duplicated switch event ${value}" // rbn.switch#L160
        runInMillis(DEBOUNCING_TIMER, switchDebouncingClear, [overwrite: true]) // rbn.switch#L161
        return // rbn.switch#L162
    } // rbn.switch#L163
    logTrace "value=${value}  lastSwitch=${state.states['lastSwitch']}" // rbn.switch#L164
    boolean isDigital = state.states['isDigital'] ?: false // rbn.switch#L165
    map.type = isDigital ? 'digital' : 'physical' // rbn.switch#L166
    if (lastSwitch != value) { // rbn.switch#L167
        logDebug "switch state changed from <b>${lastSwitch}</b> to <b>${value}</b>" // rbn.switch#L168
        state.states['debounce'] = true // rbn.switch#L169
        state.states['lastSwitch'] = value // rbn.switch#L170
        runInMillis(DEBOUNCING_TIMER, switchDebouncingClear, [overwrite: true]) // rbn.switch#L171
    } else { // rbn.switch#L172
        state.states['debounce'] = true // rbn.switch#L173
        runInMillis(DEBOUNCING_TIMER, switchDebouncingClear, [overwrite: true]) // rbn.switch#L174
    } // rbn.switch#L175
    map.name = 'switch' // rbn.switch#L176
    map.value = value // rbn.switch#L177
    if (isRefresh) { // rbn.switch#L178
        map.descriptionText = "${device.displayName} is ${value} [Refresh]" // rbn.switch#L179
        map.isStateChange = true // rbn.switch#L180
    } else { // rbn.switch#L181
        map.descriptionText = "${device.displayName} is ${value} [${map.type}]" // rbn.switch#L182
    } // rbn.switch#L183
    logInfo "${map.descriptionText}" // rbn.switch#L184
    sendEvent(map) // rbn.switch#L185
    if (this.respondsTo('customSwitchEventPostProcesing')) { // rbn.switch#L186
        customSwitchEventPostProcesing(map) // rbn.switch#L187
    } // rbn.switch#L188
} // rbn.switch#L189

void parseOnOffAttributes(final Map it) { // rbn.switch#L191
    logDebug "OnOff attribute ${it.attrId} cluster ${it.cluster } reported: value=${it.value}" // rbn.switch#L192

    String mode // rbn.switch#L194
    String attrName // rbn.switch#L195
    if (it.value == null) { // rbn.switch#L196
        logDebug "OnOff attribute ${it.attrId} cluster ${it.cluster } skipping NULL value status=${it.status}" // rbn.switch#L197
        return // rbn.switch#L198
    } // rbn.switch#L199
    int value = zigbee.convertHexToInt(it.value) // rbn.switch#L200
    switch (it.attrId) { // rbn.switch#L201
        case '4000' : // rbn.switch#L202
            attrName = 'Global Scene Control' // rbn.switch#L203
            mode = value == 0 ? 'off' : value == 1 ? 'on' : null // rbn.switch#L204
            break // rbn.switch#L205
        case '4001' : // rbn.switch#L206
            attrName = 'On Time' // rbn.switch#L207
            mode = value // rbn.switch#L208
            break // rbn.switch#L209
        case '4002' : // rbn.switch#L210
            attrName = 'Off Wait Time' // rbn.switch#L211
            mode = value // rbn.switch#L212
            break // rbn.switch#L213
        case '4003' : // rbn.switch#L214
            attrName = 'Power On State' // rbn.switch#L215
            mode = value == 0 ? 'off' : value == 1 ? 'on' : value == 2 ?  'Last state' : 'UNKNOWN' // rbn.switch#L216
            break // rbn.switch#L217
        case '8000' : // rbn.switch#L218
            attrName = 'Child Lock' // rbn.switch#L219
            mode = value == 0 ? 'off' : 'on' // rbn.switch#L220
            break // rbn.switch#L221
        case '8001' : // rbn.switch#L222
            attrName = 'LED mode' // rbn.switch#L223
            if (isCircuitBreaker()) { // rbn.switch#L224
                mode = value == 0 ? 'Always Green' : value == 1 ? 'Red when On; Green when Off' : value == 2 ? 'Green when On; Red when Off' : value == 3 ? 'Always Red' : null // rbn.switch#L225
            } // rbn.switch#L226
            else { // rbn.switch#L227
                mode = value == 0 ? 'Disabled' : value == 1 ? 'Lit when On' : value == 2 ? 'Lit when Off' : value == 3 ? 'Freeze' : null // rbn.switch#L228
            } // rbn.switch#L229
            break // rbn.switch#L230
        case '8002' : // rbn.switch#L231
            attrName = 'Power On State' // rbn.switch#L232
            mode = value == 0 ? 'off' : value == 1 ? 'on' : value == 2 ?  'Last state' : null // rbn.switch#L233
            break // rbn.switch#L234
        case '8003' : // rbn.switch#L235
            attrName = 'Over current alarm' // rbn.switch#L236
            mode = value == 0 ? 'Over Current OK' : value == 1 ? 'Over Current Alarm' : null // rbn.switch#L237
            break // rbn.switch#L238
        default : // rbn.switch#L239
            logWarn "Unprocessed Tuya OnOff attribute ${it.attrId} cluster ${it.cluster } reported: value=${it.value}" // rbn.switch#L240
            return // rbn.switch#L241
    } // rbn.switch#L242
    if (settings?.logEnable) { logInfo "${attrName} is ${mode}" } // rbn.switch#L243
} // rbn.switch#L244

List<String> onOffRefresh() { // rbn.switch#L246
    logDebug 'onOffRefresh()' // rbn.switch#L247
    List<String> cmds = zigbee.readAttribute(0x0006, 0x0000, [:], delay = 100) // rbn.switch#L248
    return cmds // rbn.switch#L249
} // rbn.switch#L250

void onOfInitializeVars( boolean fullInit = false ) { // rbn.switch#L252
    logDebug "onOfInitializeVars()... fullInit = ${fullInit}" // rbn.switch#L253
    if (fullInit || settings?.ignoreDuplicated == null) { device.updateSetting('ignoreDuplicated', true) } // rbn.switch#L254
    if (fullInit || settings?.alwaysOn == null) { device.updateSetting('alwaysOn', false) } // rbn.switch#L255
    if ((fullInit || settings?.threeStateEnable == null) && _THREE_STATE == true) { device.updateSetting('threeStateEnable', false) } // rbn.switch#L256
} // rbn.switch#L257
// ~~~~~ end include rbn.switch ~~~~~

// ~~~~~ start include rbn.level ~~~~~
library( // rbn.level#L2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee Level Library', name: 'level', namespace: 'rbn', // rbn.level#L3
    importUrl: '', documentationLink: '', // rbn.level#L4
    version: '3.2.0' // rbn.level#L5
) // rbn.level#L6
/*
 *  Zigbee Level Library
 *
 *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License. You may obtain a copy of the License at:
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 *  for the specific language governing permissions and limitations under the License.
 *
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/levelLib.groovy) at commit 0bf47407.
 *  Modified for the rbn namespace: identity changes only.
 *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/level.groovy#L22-L25
*/

static String levelLibVersion()   { '3.2.0' } // rbn.level#L28
static String levelLibStamp() { '2024/05/28 12:33 PM' } // rbn.level#L29

metadata { // rbn.level#L31
    capability 'Switch' // rbn.level#L32
    capability 'Switch Level' // rbn.level#L33
    capability 'ChangeLevel' // rbn.level#L34

    preferences { // rbn.level#L37
        if (device != null && DEVICE_TYPE != 'Device') { // rbn.level#L38
            input name: 'levelUpTransition', type: 'enum', title: '<b>Dim up transition length</b>', options: TransitionOpts.options, defaultValue: TransitionOpts.defaultValue, required: true, description: '<i>Changes the speed the light dims up. Increasing the value slows down the transition.</i>' // rbn.level#L39
            input name: 'levelDownTransition', type: 'enum', title: '<b>Dim down transition length</b>', options: TransitionOpts.options, defaultValue: TransitionOpts.defaultValue, required: true, description: '<i>Changes the speed the light dims down. Increasing the value slows down the transition.</i>' // rbn.level#L40
            input name: 'levelChangeRate', type: 'enum', title: '<b>Level change rate</b>', options: LevelRateOpts.options, defaultValue: LevelRateOpts.defaultValue, required: true, description: '<i>Changes the speed that the light changes when using <b>start level change</b> until <b>stop level change</b> is sent.</i>' // rbn.level#L41
        } // rbn.level#L42
    } // rbn.level#L43
} // rbn.level#L44

import groovy.transform.Field // rbn.level#L46

@Field static final Map TransitionOpts = [ // rbn.level#L48
    defaultValue: 0x0004, // rbn.level#L49
    options: [ // rbn.level#L50
        0x0000: 'No Delay', // rbn.level#L51
        0x0002: '200ms', // rbn.level#L52
        0x0004: '400ms', // rbn.level#L53
        0x000A: '1s', // rbn.level#L54
        0x000F: '1.5s', // rbn.level#L55
        0x0014: '2s', // rbn.level#L56
        0x001E: '3s', // rbn.level#L57
        0x0028: '4s', // rbn.level#L58
        0x0032: '5s', // rbn.level#L59
        0x0064: '10s' // rbn.level#L60
    ] // rbn.level#L61
] // rbn.level#L62

@Field static final Map LevelRateOpts = [ // rbn.level#L64
    defaultValue: 0x64, // rbn.level#L65
    options: [ 0xFF: 'Device Default', 0x16: 'Very Slow', 0x32: 'Slow', 0x64: 'Medium', 0x96: 'Medium Fast', 0xC8: 'Fast' ] // rbn.level#L66
] // rbn.level#L67

void standardParseLevelControlCluster(final Map descMap) { // rbn.level#L74
    logDebug "standardParseLevelControlCluster: 0x${descMap.value}" // rbn.level#L75
    if (descMap.attrId == '0000') { // rbn.level#L76
        if (descMap.value == null || descMap.value == 'FFFF') { logDebug "standardParseLevelControlCluster: invalid value: ${descMap.value}"; return } // rbn.level#L77
        final long rawValue = hexStrToUnsignedInt(descMap.value) // rbn.level#L78

        int scaledValue = ((rawValue as double) / 2.55F + 0.5) as int // rbn.level#L80
        sendLevelControlEvent(scaledValue) // rbn.level#L81
    } // rbn.level#L82
    else { // rbn.level#L83
        logWarn "standardParseLevelControlCluster: unprocessed LevelControl attribute ${descMap.attrId}" // rbn.level#L84
    } // rbn.level#L85
} // rbn.level#L86

void sendLevelControlEvent(final int rawValue) { // rbn.level#L88
    int value = rawValue as int // rbn.level#L89
    if (value < 0) { value = 0 } // rbn.level#L90
    if (value > 100) { value = 100 } // rbn.level#L91
    Map map = [:] // rbn.level#L92

    boolean isDigital = state.states['isDigital'] // rbn.level#L94
    map.type = isDigital == true ? 'digital' : 'physical' // rbn.level#L95

    map.name = 'level' // rbn.level#L97
    map.value = value // rbn.level#L98
    boolean isRefresh = state.states['isRefresh'] ?: false // rbn.level#L99
    if (isRefresh == true) { // rbn.level#L100
        map.descriptionText = "${device.displayName} is ${value} [Refresh]" // rbn.level#L101
        map.isStateChange = true // rbn.level#L102
    } // rbn.level#L103
    else { // rbn.level#L104
        map.descriptionText = "${device.displayName} was set ${value} [${map.type}]" // rbn.level#L105
    } // rbn.level#L106
    logInfo "${map.descriptionText}" // rbn.level#L107
    sendEvent(map) // rbn.level#L108
    clearIsDigital() // rbn.level#L109
} // rbn.level#L110

void setLevel(final BigDecimal value, final BigDecimal transitionTime = null) { // rbn.level#L118
    logInfo "setLevel (${value}, ${transitionTime})" // rbn.level#L119

    setLevelBulb(value.intValue(), transitionTime ? transitionTime.intValue() : null) // rbn.level#L128
    return // rbn.level#L129

} // rbn.level#L136

void setLevelBulb(value, rate=null) { // rbn.level#L139
    logDebug "setLevelBulb: $value, $rate" // rbn.level#L140

    state.pendingLevelChange = value // rbn.level#L142
    if (state.cmds == null) { // rbn.level#L143
        state.cmds = [] // rbn.level#L144
    } // rbn.level#L145
    if (rate == null) { // rbn.level#L146
        state.cmds += zigbee.setLevel(value) // rbn.level#L147
    } else { // rbn.level#L148
        state.cmds += zigbee.setLevel(value, rate * 10) // rbn.level#L149
    } // rbn.level#L150

    unschedule(sendLevelZigbeeCommandsDelayed) // rbn.level#L152
    runInMillis(100, sendLevelZigbeeCommandsDelayed) // rbn.level#L153
} // rbn.level#L154

void sendLevelZigbeeCommandsDelayed() { // rbn.level#L156
    List cmds = state.cmds // rbn.level#L157
    if (cmds != null) { // rbn.level#L158
        state.cmds = [] // rbn.level#L159
        sendZigbeeCommands(cmds) // rbn.level#L160
    } // rbn.level#L161
} // rbn.level#L162

private List<String> setLevelPrivate(final BigDecimal value, final int rate = 0, final int delay = 0, final Boolean levelPreset = false) { // rbn.level#L170
    List<String> cmds = [] // rbn.level#L171
    final Integer level = constrain(value) // rbn.level#L172

    if (device.currentValue('switch') == 'off' && level > 0 && levelPreset == false) { // rbn.level#L176

        cmds += zigbee.command(zigbee.LEVEL_CONTROL_CLUSTER, 0x00, [destEndpoint:safeToInt(getDestinationEP())], delay, "00 0000 ${PRE_STAGING_OPTION}") // rbn.level#L178
    } // rbn.level#L179

    int duration = 10 // rbn.level#L186
    String endpointId = '01' // rbn.level#L187
    cmds +=  ["he cmd 0x${device.deviceNetworkId} 0x${endpointId} 0x0008 4 { 0x${intTo8bitUnsignedHex(level)} 0x${intTo16bitUnsignedHex(duration)} }",] // rbn.level#L188

    return cmds // rbn.level#L190
} // rbn.level#L191

private Integer getLevelTransitionRate(final Integer desiredLevel, final Integer transitionTime = null) { // rbn.level#L200
    int rate = 0 // rbn.level#L201
    final Boolean isOn = device.currentValue('switch') == 'on' // rbn.level#L202
    Integer currentLevel = (device.currentValue('level') as Integer) ?: 0 // rbn.level#L203
    if (!isOn) { // rbn.level#L204
        currentLevel = 0 // rbn.level#L205
    } // rbn.level#L206

    if (transitionTime > 0) { // rbn.level#L208

        rate = transitionTime * 10 // rbn.level#L210
    } else { // rbn.level#L211

        if (((settings.levelUpTransition ?: 0) as Integer) > 0 && currentLevel < desiredLevel) { // rbn.level#L213

            rate = settings.levelUpTransition.toInteger() // rbn.level#L215
        } // rbn.level#L216

        else if (((settings.levelDownTransition ?: 0) as Integer) > 0 && currentLevel > desiredLevel) { // rbn.level#L218

            rate = settings.levelDownTransition.toInteger() // rbn.level#L220
        } // rbn.level#L221
    } // rbn.level#L222
    logDebug "using level transition rate ${rate}" // rbn.level#L223
    return rate // rbn.level#L224
} // rbn.level#L225

List<String> startLevelChange(String direction) { // rbn.level#L227
    if (settings.txtEnable) { log.info "startLevelChange (${direction})" } // rbn.level#L228
    String upDown = direction == 'down' ? '01' : '00' // rbn.level#L229
    String rateHex = intToHexStr(settings.levelChangeRate as Integer) // rbn.level#L230
    scheduleCommandTimeoutCheck() // rbn.level#L231
    return zigbee.command(zigbee.LEVEL_CONTROL_CLUSTER, 0x05, [:], 0, "${upDown} ${rateHex}") // rbn.level#L232
} // rbn.level#L233

List<String> stopLevelChange() { // rbn.level#L235
    if (settings.txtEnable) { log.info 'stopLevelChange' } // rbn.level#L236
    scheduleCommandTimeoutCheck() // rbn.level#L237
    return zigbee.command(zigbee.LEVEL_CONTROL_CLUSTER, 0x03, [:], 0) + // rbn.level#L238
        ifPolling { zigbee.levelRefresh(0) + zigbee.onOffRefresh(0) } // rbn.level#L239
} // rbn.level#L240

@Field static final int POLL_DELAY_MS = 1000 // rbn.level#L243

@Field static final String PRE_STAGING_OPTION = '01 01' // rbn.level#L245

private List<String> ifPolling(final int delayMs = 0, final Closure commands) { // rbn.level#L254
    if (state.reportingEnabled == false) { // rbn.level#L255
        final int value = Math.max(delayMs, POLL_DELAY_MS) // rbn.level#L256
        return ["delay ${value}"] + (commands() as List<String>) as List<String> // rbn.level#L257
    } // rbn.level#L258
    return [] // rbn.level#L259
} // rbn.level#L260

private static BigDecimal constrain(final BigDecimal value, final BigDecimal min = 0, final BigDecimal max = 100, final BigDecimal nullValue = 0) { // rbn.level#L269
    if (min == null || max == null) { // rbn.level#L270
        return value // rbn.level#L271
    } // rbn.level#L272
    return value != null ? max.min(value.max(min)) : nullValue // rbn.level#L273
} // rbn.level#L274

private static Integer constrain(final Object value, final Integer min = 0, final Integer max = 100, final Integer nullValue = 0) { // rbn.level#L283
    if (min == null || max == null) { // rbn.level#L284
        return value as Integer // rbn.level#L285
    } // rbn.level#L286
    return value != null ? Math.min(Math.max(value as Integer, min) as Integer, max) : nullValue // rbn.level#L287
} // rbn.level#L288

void updatedLevel() { // rbn.level#L290
    logDebug "updatedLevel: ${device.currentValue('level')}" // rbn.level#L291
} // rbn.level#L292

List<String> levelRefresh() { // rbn.level#L294
    List<String> cmds = zigbee.onOffRefresh(100) + zigbee.levelRefresh(101) // rbn.level#L295
    return cmds // rbn.level#L296
} // rbn.level#L297
// ~~~~~ end include rbn.level ~~~~~

// ~~~~~ start include rbn.meter ~~~~~
library( // rbn.meter#L2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee Energy Library', name: 'meter', namespace: 'rbn', // rbn.meter#L3
    importUrl: '', documentationLink: '', // rbn.meter#L4
    version: '3.3.0' // rbn.meter#L5

) // rbn.meter#L7
/*
 *  Zigbee Energy Library
 *
 *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License. You may obtain a copy of the License at:
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 *  for the specific language governing permissions and limitations under the License.
 *
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/energyLib.groovy) at commit 0bf47407.
 *  Modified for the rbn namespace: identity changes only.
 *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/meter.groovy#L23-L27
*/

static String energyLibVersion()   { '3.3.0' } // rbn.meter#L30
static String energyLibStamp() { '2024/06/09 6:53 PM' } // rbn.meter#L31

metadata { // rbn.meter#L33
    capability 'PowerMeter' // rbn.meter#L34
    capability 'EnergyMeter' // rbn.meter#L35
    capability 'VoltageMeasurement' // rbn.meter#L36
    capability 'CurrentMeter' // rbn.meter#L37

    preferences { // rbn.meter#L40

    } // rbn.meter#L42
} // rbn.meter#L43

@Field static final int AC_CURRENT_DIVISOR_ID = 0x0603 // rbn.meter#L45
@Field static final int AC_CURRENT_MULTIPLIER_ID = 0x0602 // rbn.meter#L46
@Field static final int AC_FREQUENCY_ID = 0x0300 // rbn.meter#L47
@Field static final int AC_POWER_DIVISOR_ID = 0x0605 // rbn.meter#L48
@Field static final int AC_POWER_MULTIPLIER_ID = 0x0604 // rbn.meter#L49
@Field static final int AC_VOLTAGE_DIVISOR_ID = 0x0601 // rbn.meter#L50
@Field static final int AC_VOLTAGE_MULTIPLIER_ID = 0x0600 // rbn.meter#L51
@Field static final int ACTIVE_POWER_ID = 0x050B // rbn.meter#L52
@Field static final int POWER_ON_OFF_ID = 0x0000 // rbn.meter#L53
@Field static final int POWER_RESTORE_ID = 0x4003 // rbn.meter#L54
@Field static final int RMS_CURRENT_ID = 0x0508 // rbn.meter#L55
@Field static final int RMS_VOLTAGE_ID = 0x0505 // rbn.meter#L56
@Field static final int CURRENT_SUMMATION_DELIVERED = 0x0000 // rbn.meter#L57

@Field static  int    DEFAULT_REPORTING_TIME = 30 // rbn.meter#L59
@Field static  int    DEFAULT_PRECISION = 3 // rbn.meter#L60
@Field static  BigDecimal DEFAULT_DELTA = 0.001 // rbn.meter#L61
@Field static  int    MAX_POWER_LIMIT = 999 // rbn.meter#L62

void sendVoltageEvent(BigDecimal voltage, boolean isDigital=false) { // rbn.meter#L64
    Map map = [:] // rbn.meter#L65
    map.name = 'voltage' // rbn.meter#L66
    map.value = voltage.setScale((settings?.defaultPrecision ?: DEFAULT_PRECISION) as int, BigDecimal.ROUND_HALF_UP) // rbn.meter#L67
    map.unit = 'V' // rbn.meter#L68
    map.type = isDigital == true ? 'digital' : 'physical' // rbn.meter#L69
    map.descriptionText = "${map.name} is ${map.value} ${map.unit}" // rbn.meter#L70
    if (state.states.isRefresh == true) { map.descriptionText += ' (refresh)' } // rbn.meter#L71
    final BigDecimal lastVoltage = device.currentValue('voltage') ?: 0.0 // rbn.meter#L72
    final BigDecimal  voltageThreshold = DEFAULT_DELTA // rbn.meter#L73
    if (Math.abs(voltage - lastVoltage) >= voltageThreshold || state.states.isRefresh == true) { // rbn.meter#L74
        logInfo "${map.descriptionText}" // rbn.meter#L75
        sendEvent(map) // rbn.meter#L76
    } // rbn.meter#L77
    else { // rbn.meter#L78
        logDebug "ignored ${map.name} ${map.value} ${map.unit} (change from ${lastVoltage} is less than ${voltageThreshold} V)" // rbn.meter#L79
    } // rbn.meter#L80
} // rbn.meter#L81

void sendAmperageEvent(BigDecimal amperage, boolean isDigital=false) { // rbn.meter#L83
    Map map = [:] // rbn.meter#L84
    map.name = 'amperage' // rbn.meter#L85
    map.value = amperage.setScale((settings?.defaultPrecision ?: DEFAULT_PRECISION) as int, BigDecimal.ROUND_HALF_UP) // rbn.meter#L86
    map.unit = 'A' // rbn.meter#L87
    map.type = isDigital == true ? 'digital' : 'physical' // rbn.meter#L88
    map.descriptionText = "${map.name} is ${map.value} ${map.unit}" // rbn.meter#L89
    if (state.states.isRefresh  == true) { map.descriptionText += ' (refresh)' } // rbn.meter#L90
    final BigDecimal lastAmperage = device.currentValue('amperage') ?: 0.00000001 // rbn.meter#L91
    final BigDecimal amperageThreshold = DEFAULT_DELTA // rbn.meter#L92
    if (Math.abs(amperage - lastAmperage ) >= amperageThreshold || state.states.isRefresh  == true) { // rbn.meter#L93
        logInfo "${map.descriptionText}" // rbn.meter#L94
        sendEvent(map) // rbn.meter#L95
    } // rbn.meter#L96
    else { // rbn.meter#L97
        logDebug "ignored ${map.name} ${map.value} ${map.unit} (change from ${lastAmperage} is less than ${amperageThreshold} mA)" // rbn.meter#L98
    } // rbn.meter#L99
} // rbn.meter#L100

void sendPowerEvent(BigDecimal power, boolean isDigital=false) { // rbn.meter#L102
    Map map = [:] // rbn.meter#L103
    map.name = 'power' // rbn.meter#L104
    map.value = power.setScale((settings?.defaultPrecision ?: DEFAULT_PRECISION) as int, BigDecimal.ROUND_HALF_UP) // rbn.meter#L105
    map.unit = 'W' // rbn.meter#L106
    map.type = isDigital == true ? 'digital' : 'physical' // rbn.meter#L107
    map.descriptionText = "${map.name} is ${map.value} ${map.unit}" // rbn.meter#L108
    if (state.states.isRefresh == true) { map.descriptionText += ' (refresh)' } // rbn.meter#L109
    final BigDecimal lastPower = device.currentValue('power') ?: 0.00000001 // rbn.meter#L110
    final BigDecimal powerThreshold = DEFAULT_DELTA // rbn.meter#L111
    if (power  > MAX_POWER_LIMIT) { // rbn.meter#L112
        logDebug "ignored ${map.name} ${map.value} ${map.unit} (exceeds maximum power cap ${MAX_POWER_LIMIT} W)" // rbn.meter#L113
        return // rbn.meter#L114
    } // rbn.meter#L115
    if (Math.abs(power - lastPower ) >= powerThreshold || state.states.isRefresh == true) { // rbn.meter#L116
        logInfo "${map.descriptionText}" // rbn.meter#L117
        sendEvent(map) // rbn.meter#L118
    } // rbn.meter#L119
    else { // rbn.meter#L120
        logDebug "ignored ${map.name} ${map.value} ${map.unit} (change from ${lastPower} is less than ${powerThreshold} W)" // rbn.meter#L121
    } // rbn.meter#L122
} // rbn.meter#L123

void sendFrequencyEvent(BigDecimal frequency, boolean isDigital=false) { // rbn.meter#L125
    Map map = [:] // rbn.meter#L126
    map.name = 'frequency' // rbn.meter#L127
    map.value = frequency.setScale(1, BigDecimal.ROUND_HALF_UP) // rbn.meter#L128
    map.unit = 'Hz' // rbn.meter#L129
    map.type = isDigital == true ? 'digital' : 'physical' // rbn.meter#L130
    map.descriptionText = "${map.name} is ${map.value} ${map.unit}" // rbn.meter#L131
    if (state.states.isRefresh == true) { map.descriptionText += ' (refresh)' } // rbn.meter#L132
    final BigDecimal lastFrequency = device.currentValue('frequency') ?: 0.00000001 // rbn.meter#L133
    final BigDecimal frequencyThreshold = 0.1 // rbn.meter#L134
    if (Math.abs(frequency - lastFrequency) >= frequencyThreshold || state.states.isRefresh == true) { // rbn.meter#L135
        logInfo "${map.descriptionText}" // rbn.meter#L136
        sendEvent(map) // rbn.meter#L137
    } // rbn.meter#L138
    else { // rbn.meter#L139
        logDebug "ignored ${map.name} ${map.value} ${map.unit} (change from ${lastFrequency} is less than ${frequencyThreshold} Hz)" // rbn.meter#L140
    } // rbn.meter#L141
} // rbn.meter#L142

void sendPowerFactorEvent(BigDecimal pf, boolean isDigital=false) { // rbn.meter#L144
    Map map = [:] // rbn.meter#L145
    map.name = 'powerFactor' // rbn.meter#L146
    map.value = pf.setScale(2, BigDecimal.ROUND_HALF_UP) // rbn.meter#L147
    map.unit = '%' // rbn.meter#L148
    map.type = isDigital == true ? 'digital' : 'physical' // rbn.meter#L149
    map.descriptionText = "${map.name} is ${map.value} ${map.unit}" // rbn.meter#L150
    if (state.states.isRefresh == true) { map.descriptionText += ' (refresh)' } // rbn.meter#L151
    final BigDecimal lastPF = device.currentValue('powerFactor') ?: 0.00000001 // rbn.meter#L152
    final BigDecimal powerFactorThreshold = 0.01 // rbn.meter#L153
    if (Math.abs(pf - lastPF) >= powerFactorThreshold || state.states.isRefresh == true) { // rbn.meter#L154
        logInfo "${map.descriptionText}" // rbn.meter#L155
        sendEvent(map) // rbn.meter#L156
    } // rbn.meter#L157
    else { // rbn.meter#L158
        logDebug "ignored ${map.name} ${map.value} ${map.unit} (change from ${lastFrequency} is less than ${powerFactorThreshold} %)" // rbn.meter#L159
    } // rbn.meter#L160
} // rbn.meter#L161

void sendEnergyEvent(BigDecimal energy_total, boolean isDigital=false) { // rbn.meter#L163
    BigDecimal energy = energy_total // rbn.meter#L164
    Map map = [:] // rbn.meter#L165
    logDebug "energy_total=${energy_total}" // rbn.meter#L166
    map.name = 'energy' // rbn.meter#L167
    map.value = energy // rbn.meter#L168
    map.unit = 'kWh' // rbn.meter#L169
    map.type = isDigital == true ? 'digital' : 'physical' // rbn.meter#L170
    if (isDigital == true) { map.isStateChange = true  } // rbn.meter#L171
    map.descriptionText = "${map.name} is ${map.value} ${map.unit}" // rbn.meter#L172
    if (state.states.isRefreshRequest == true) { map.descriptionText += ' (refresh)' } // rbn.meter#L173
    BigDecimal lastEnergy = device.currentValue('energy') ?: 0.00000001 // rbn.meter#L174
    if (lastEnergy  != energy || state.states.isRefreshRequest == true || isDigital == true) { // rbn.meter#L175
        sendEvent(map) // rbn.meter#L176
        logInfo "${map.descriptionText}" // rbn.meter#L177
    } // rbn.meter#L178
    else { // rbn.meter#L179
        logDebug "${device.displayName} ${map.name} is ${map.value} ${map.unit} (no change)" // rbn.meter#L180
    } // rbn.meter#L181
} // rbn.meter#L182

boolean standardParseElectricalMeasureCluster(Map descMap) { // rbn.meter#L185
    if (descMap.value == null || descMap.value == 'FFFF') { return true } // rbn.meter#L186
    int value = hexStrToUnsignedInt(descMap.value) // rbn.meter#L187
    int attributeInt = hexStrToUnsignedInt(descMap.attrId) // rbn.meter#L188
    logTrace "standardParseElectricalMeasureCluster: (0x0B04)  attribute 0x${descMap.attrId} descMap.value=${descMap.value} value=${value}" // rbn.meter#L189
    switch (attributeInt) { // rbn.meter#L190
        case ACTIVE_POWER_ID: // rbn.meter#L191
            BigDecimal power = new BigDecimal(value).divide(new BigDecimal(1 )) // rbn.meter#L192
            sendPowerEvent(power) // rbn.meter#L193
            break // rbn.meter#L194
        case RMS_CURRENT_ID: // rbn.meter#L195
            BigDecimal current = new BigDecimal(value).divide(new BigDecimal(1000)) // rbn.meter#L196
            sendAmperageEvent(current) // rbn.meter#L197
            break // rbn.meter#L198
        case RMS_VOLTAGE_ID: // rbn.meter#L199
            BigDecimal voltage = new BigDecimal(value).divide(new BigDecimal(10)) // rbn.meter#L200
            sendVoltageEvent(voltage) // rbn.meter#L201
            break // rbn.meter#L202
        case AC_FREQUENCY_ID: // rbn.meter#L203
            BigDecimal frequency = new BigDecimal(value).divide(new BigDecimal(10)) // rbn.meter#L204
            sendFrequencyEvent(frequency) // rbn.meter#L205
            break // rbn.meter#L206
        case 0x0800: // rbn.meter#L207
            logDebug "standardParseElectricalMeasureCluster: (0x0B04)  attribute 0x${descMap.attrId} AC Alarms Mask value=${value}" // rbn.meter#L208
            break // rbn.meter#L209
        case 0x0802: // rbn.meter#L210
            logDebug "standardParseElectricalMeasureCluster: (0x0B04)  attribute 0x${descMap.attrId} AC Current Overload value=${value / 1000} (raw: ${value})" // rbn.meter#L211
            break // rbn.meter#L212
        case [AC_VOLTAGE_MULTIPLIER_ID, AC_VOLTAGE_DIVISOR_ID, AC_CURRENT_MULTIPLIER_ID, AC_CURRENT_DIVISOR_ID, AC_POWER_MULTIPLIER_ID, AC_POWER_DIVISOR_ID].contains(descMap.attrId): // rbn.meter#L213
            logDebug "standardParseElectricalMeasureCluster: (0x0B04)  attribute 0x${descMap.attrId} descMap.value=${descMap.value} value=${value}" // rbn.meter#L214
            break // rbn.meter#L215
        default: // rbn.meter#L216
            logDebug "standardParseElectricalMeasureCluster: (0x0B04) <b>not parsed</b> attribute 0x${descMap.attrId} descMap.value=${descMap.value} value=${value}" // rbn.meter#L217
            return false // rbn.meter#L218
    } // rbn.meter#L219
    return true // rbn.meter#L220
} // rbn.meter#L221

boolean standardParseMeteringCluster(Map descMap) { // rbn.meter#L224
    if (descMap.value == null || descMap.value == 'FFFF') { return true } // rbn.meter#L225
    int value = hexStrToUnsignedInt(descMap.value) // rbn.meter#L226
    int attributeInt = hexStrToUnsignedInt(descMap.attrId) // rbn.meter#L227
    logTrace "standardParseMeteringCluster: (0x0702)  attribute 0x${descMap.attrId} descMap.value=${descMap.value} value=${value}" // rbn.meter#L228
    switch (attributeInt) { // rbn.meter#L229
        case CURRENT_SUMMATION_DELIVERED: // rbn.meter#L230
            BigDecimal energyScaled = new BigDecimal(value).divide(new BigDecimal(10 )) // rbn.meter#L231
            sendEnergyEvent(energyScaled) // rbn.meter#L232
            break // rbn.meter#L233
        default: // rbn.meter#L234
            logWarn "standardParseMeteringCluster: (0x0702) <b>not parsed</b> attribute 0x${descMap.attrId} descMap.value=${descMap.value} value=${value}" // rbn.meter#L235
            return false // rbn.meter#L236
    } // rbn.meter#L237
    return true // rbn.meter#L238
} // rbn.meter#L239

void energyInitializeVars( boolean fullInit = false ) { // rbn.meter#L241
    logDebug "energyInitializeVars()... fullInit = ${fullInit}" // rbn.meter#L242
    if (fullInit || settings?.defaultPrecision == null) { device.updateSetting('defaultPrecision', [value: DEFAULT_PRECISION, type: 'number']) } // rbn.meter#L243
} // rbn.meter#L244
// ~~~~~ end include rbn.meter ~~~~~

// ~~~~~ start include rbn.reporting ~~~~~
library( // rbn.reporting#L2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee Reporting Config Library', name: 'reporting', namespace: 'rbn', // rbn.reporting#L3
    importUrl: '', documentationLink: '', // rbn.reporting#L4
    version: '3.2.1' // rbn.reporting#L5
) // rbn.reporting#L6
/*
 *  Zigbee Reporting Config Library
 *
 *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License. You may obtain a copy of the License at:
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 *  for the specific language governing permissions and limitations under the License.
 *
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/reportingLib.groovy) at commit 0bf47407.
 *  Modified for the rbn namespace: identity changes only.
 *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/reporting.groovy#L22-L25
*/

static String reportingLibVersion()   { '3.2.1' } // rbn.reporting#L28
static String reportingLibStamp() { '2025/03/23 7:31 PM' } // rbn.reporting#L29

metadata { // rbn.reporting#L31

    preferences { // rbn.reporting#L35

    } // rbn.reporting#L37
} // rbn.reporting#L38

@Field static final String ONOFF = 'Switch' // rbn.reporting#L40
@Field static final String POWER = 'Power' // rbn.reporting#L41
@Field static final String INST_POWER = 'InstPower' // rbn.reporting#L42
@Field static final String ENERGY = 'Energy' // rbn.reporting#L43
@Field static final String VOLTAGE = 'Voltage' // rbn.reporting#L44
@Field static final String AMPERAGE = 'Amperage' // rbn.reporting#L45
@Field static final String FREQUENCY = 'Frequency' // rbn.reporting#L46
@Field static final String POWER_FACTOR = 'PowerFactor' // rbn.reporting#L47

List<String> configureReportingInt(String operation, String measurement,  int minTime=0, int maxTime=0, int delta=0, boolean sendNow=true ) { // rbn.reporting#L49
    configureReporting(operation, measurement, minTime.toString(), maxTime.toString(), delta.toString(), sendNow) // rbn.reporting#L50
} // rbn.reporting#L51

List<String> configureReporting(String operation, String measurement,  String minTime='0', String maxTime='0', String delta='0', boolean sendNow=true ) { // rbn.reporting#L53
    int intMinTime = safeToInt(minTime) // rbn.reporting#L54
    int intMaxTime = safeToInt(maxTime) // rbn.reporting#L55
    int intDelta = safeToInt(delta) // rbn.reporting#L56
    String epString = state.destinationEP // rbn.reporting#L57
    int ep = safeToInt(epString) // rbn.reporting#L58
    if (ep == null || ep == 0) { // rbn.reporting#L59
        ep = 1 // rbn.reporting#L60
        epString = '01' // rbn.reporting#L61
    } // rbn.reporting#L62

    logDebug "configureReporting operation=${operation}, measurement=${measurement}, minTime=${intMinTime}, maxTime=${intMaxTime}, delta=${intDelta} )" // rbn.reporting#L64

    List<String> cmds = [] // rbn.reporting#L66

    switch (measurement) { // rbn.reporting#L68
        case ONOFF : // rbn.reporting#L69
            if (operation == 'Write') { // rbn.reporting#L70
                cmds += ["zdo bind 0x${device.deviceNetworkId} 0x${epString} 0x01 0x0006 {${device.zigbeeId}} {}", 'delay 251', ] // rbn.reporting#L71
                cmds += ["he cr 0x${device.deviceNetworkId} 0x${epString} 6 0 16 ${intMinTime} ${intMaxTime} {}", 'delay 251', ] // rbn.reporting#L72
            } // rbn.reporting#L73
            else if (operation == 'Disable') { // rbn.reporting#L74
                cmds += ["he cr 0x${device.deviceNetworkId} 0x${epString} 6 0 16 65535 65535 {}", 'delay 251', ] // rbn.reporting#L75
            } // rbn.reporting#L76
            cmds +=  zigbee.reportingConfiguration(0x0006, 0x0000, [destEndpoint :ep], 251) // rbn.reporting#L77
            break // rbn.reporting#L78
        case ENERGY : // rbn.reporting#L79
            if (operation == 'Write') { // rbn.reporting#L80
                cmds += zigbee.configureReporting(0x0702, 0x0000,  DataType.UINT48, intMinTime, intMaxTime, (intDelta * getEnergyDiv() as int)) // rbn.reporting#L81
            } // rbn.reporting#L82
            else if (operation == 'Disable') { // rbn.reporting#L83
                cmds += zigbee.configureReporting(0x0702, 0x0000,  DataType.UINT48, 0xFFFF, 0xFFFF, 0x0000) // rbn.reporting#L84
            } // rbn.reporting#L85
            cmds += zigbee.reportingConfiguration(0x0702, 0x0000, [destEndpoint :ep], 252) // rbn.reporting#L86
            break // rbn.reporting#L87
        case INST_POWER : // rbn.reporting#L88
            if (operation == 'Write') { // rbn.reporting#L89
                cmds += zigbee.configureReporting(0x0702, 0x0400,  DataType.INT16, intMinTime, intMaxTime, (intDelta * getPowerDiv() as int)) // rbn.reporting#L90
            } // rbn.reporting#L91
            else if (operation == 'Disable') { // rbn.reporting#L92
                cmds += zigbee.configureReporting(0x0702, 0x0400,  DataType.INT16, 0xFFFF, 0xFFFF, 0x0000) // rbn.reporting#L93
            } // rbn.reporting#L94
            cmds += zigbee.reportingConfiguration(0x0702, 0x0400, [destEndpoint :ep], 253) // rbn.reporting#L95
            break // rbn.reporting#L96
        case POWER : // rbn.reporting#L97
            if (operation == 'Write') { // rbn.reporting#L98
                cmds += zigbee.configureReporting(0x0B04, 0x050B,  DataType.INT16, intMinTime, intMaxTime, (intDelta * getPowerDiv() as int) ) // rbn.reporting#L99
            } // rbn.reporting#L100
            else if (operation == 'Disable') { // rbn.reporting#L101
                cmds += zigbee.configureReporting(0x0B04, 0x050B,  DataType.INT16, 0xFFFF, 0xFFFF, 0x8000) // rbn.reporting#L102
            } // rbn.reporting#L103
            cmds += zigbee.reportingConfiguration(0x0B04, 0x050B, [destEndpoint :ep], 254) // rbn.reporting#L104
            break // rbn.reporting#L105
        case VOLTAGE : // rbn.reporting#L106
            if (operation == 'Write') { // rbn.reporting#L107
                cmds += zigbee.configureReporting(0x0B04, 0x0505,  DataType.UINT16, intMinTime, intMaxTime, (intDelta * getVoltageDiv() as int)) // rbn.reporting#L108
            } // rbn.reporting#L109
            else if (operation == 'Disable') { // rbn.reporting#L110
                cmds += zigbee.configureReporting(0x0B04, 0x0505,  DataType.UINT16, 0xFFFF, 0xFFFF, 0xFFFF) // rbn.reporting#L111
            } // rbn.reporting#L112
            cmds += zigbee.reportingConfiguration(0x0B04, 0x0505, [destEndpoint :ep], 255) // rbn.reporting#L113
            break // rbn.reporting#L114
        case AMPERAGE : // rbn.reporting#L115
            if (operation == 'Write') { // rbn.reporting#L116
                cmds += zigbee.configureReporting(0x0B04, 0x0508,  DataType.UINT16, intMinTime, intMaxTime, (intDelta * getCurrentDiv() as int)) // rbn.reporting#L117
            } // rbn.reporting#L118
            else if (operation == 'Disable') { // rbn.reporting#L119
                cmds += zigbee.configureReporting(0x0B04, 0x0508,  DataType.UINT16, 0xFFFF, 0xFFFF, 0xFFFF) // rbn.reporting#L120
            } // rbn.reporting#L121
            cmds += zigbee.reportingConfiguration(0x0B04, 0x0508, [destEndpoint :ep], 256) // rbn.reporting#L122
            break // rbn.reporting#L123
        case FREQUENCY : // rbn.reporting#L124
            if (operation == 'Write') { // rbn.reporting#L125
                cmds += zigbee.configureReporting(0x0B04, 0x0300,  DataType.UINT16, intMinTime, intMaxTime, (intDelta * getFrequencyDiv() as int)) // rbn.reporting#L126
            } // rbn.reporting#L127
            else if (operation == 'Disable') { // rbn.reporting#L128
                cmds += zigbee.configureReporting(0x0B04, 0x0300,  DataType.UINT16, 0xFFFF, 0xFFFF, 0xFFFF) // rbn.reporting#L129
            } // rbn.reporting#L130
            cmds += zigbee.reportingConfiguration(0x0B04, 0x0300, [destEndpoint :ep], 257) // rbn.reporting#L131
            break // rbn.reporting#L132
        case POWER_FACTOR : // rbn.reporting#L133
            if (operation == 'Write') { // rbn.reporting#L134
                cmds += zigbee.configureReporting(0x0B04, 0x0510,  DataType.UINT16, intMinTime, intMaxTime, (intDelta * getPowerFactorDiv() as int)) // rbn.reporting#L135
            } // rbn.reporting#L136
            cmds += zigbee.reportingConfiguration(0x0B04, 0x0510, [destEndpoint :ep], 258) // rbn.reporting#L137
            break // rbn.reporting#L138
        default : // rbn.reporting#L139
            break // rbn.reporting#L140
    } // rbn.reporting#L141
    if (cmds != null) { // rbn.reporting#L142
        if (sendNow == true) { // rbn.reporting#L143
            sendZigbeeCommands(cmds) // rbn.reporting#L144
        } // rbn.reporting#L145
        else { // rbn.reporting#L146
            return cmds // rbn.reporting#L147
        } // rbn.reporting#L148
    } // rbn.reporting#L149
} // rbn.reporting#L150
// ~~~~~ end include rbn.reporting ~~~~~
