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
 *  The standard-cluster seed of the full rbn VZM31-SN driver: on/off, level, energy, and power through the
 *  rbn libraries and nothing from Inovelli's private cluster 0xFC31 (parameters, LED notifications, scene
 *  buttons). The full driver extends this file in place, under this name and HPM identity.
 *
 *  `voltage` and `amperage` capabilities come from rbn.meter; this device does not report them.
 *  The device reports energy (0x0702:0x0000) in hundredths of a kWh and power (0x0B04:0x050B) in tenths of a
 *  watt, where rbn.meter assumes tenths and whole units; the two customParse* methods below apply the
 *  device's scale and hand everything else to the library.
 *
 *  Fingerprints and metering scale are taken from Inovelli's driver,
 *  https://github.com/InovelliUSA/Hubitat (Drivers/inovelli-dimmer-blue-series-vzm31-sn.src).
 *
 * ver. 0.1.0  2026-10-02 rbn  - standard clusters only
 * ver. 0.1.1  2026-10-02 rbn  - runtime validated on a VZM31-SN (refresh, on/off, physical switch and dim, power ÷10, energy ÷100, 0xFC31 ignored)
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

// #include rbn.common  -- included at line 100
// #include rbn.switch  -- included at line 1341
// #include rbn.level  -- included at line 1584
// #include rbn.meter  -- included at line 1812
// #include rbn.reporting  -- included at line 2050

metadata {
    definition(
        name: 'Inovelli Dimmer (Blue, VZM31-SN)',
        importUrl: 'https://raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/drivers/inovelli-vzm31-sn/inovelli-vzm31-sn.bundled.groovy',
        namespace: 'rbn', author: 'John Muchovej', singleThreaded: true)
    {
        capability 'Sensor'
    }

    fingerprint profileId:'0104', endpointId:'01', inClusters:'0000,0003,0004,0005,0006,0008,0702,0B04,0B05,FC57,FC31', outClusters:'0003,0019',           model:'VZM31-SN', manufacturer:'Inovelli', deviceJoinName: 'Inovelli Dimmer (Blue)'
    fingerprint profileId:'0104', endpointId:'02', inClusters:'0000,0003',                                              outClusters:'0003,0019,0006,0008', model:'VZM31-SN', manufacturer:'Inovelli', deviceJoinName: 'Inovelli Dimmer (Blue)'

    preferences {
        input name: 'txtEnable', type: 'bool', title: '<b>Enable descriptionText logging</b>', defaultValue: true, description: '<i>Enables command logging.</i>'
        input name: 'logEnable', type: 'bool', title: '<b>Enable debug logging</b>', defaultValue: true, description: '<i>Turns on debug logging for 24 hours.</i>'
    }
}

// One list, one dispatch: rbn.common's refresh() hands this to sendZigbeeCommands() once.
List<String> customRefresh() {
    List<String> cmds = zigbee.onOffRefresh() + zigbee.levelRefresh() + zigbee.readAttribute(0x0702, 0x0000) + zigbee.readAttribute(0x0B04, 0x050B)
    logDebug "customRefresh() : ${cmds}"
    return cmds
}

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
  *  Tuya command builders and constants, tuyaTest/tuyaBlackMagic/queryAllTuyaDP, isTuya/updateTuyaVersion); identity.
  *
  * This library is inspired by @w35l3y work on Tuya device driver (Edge project).
  * For a big portions of code all credits go to Jonathan Bradshaw.
  *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/common.groovy#L27-L51
*/

String commonLibVersion() { '4.1.1' } // rbn.common#L54
String commonLibStamp() { '2026/08/23 4:28 PM' } // rbn.common#L55

import groovy.transform.Field // rbn.common#L57
import hubitat.device.HubMultiAction // rbn.common#L58
import hubitat.device.Protocol // rbn.common#L59
import hubitat.helper.HexUtils // rbn.common#L60
import hubitat.zigbee.zcl.DataType // rbn.common#L61
import java.util.concurrent.ConcurrentHashMap // rbn.common#L62
import groovy.json.JsonOutput // rbn.common#L63
import groovy.transform.CompileStatic // rbn.common#L64
import java.math.BigDecimal // rbn.common#L65

metadata { // rbn.common#L67
        if (_DEBUG) { // rbn.common#L68
            command 'test', [[name: 'test', type: 'STRING', description: 'test', defaultValue : '']] // rbn.common#L69
            command 'testParse', [[name: 'testParse', type: 'STRING', description: 'testParse', defaultValue : '']] // rbn.common#L70
        } // rbn.common#L71

        capability 'Configuration' // rbn.common#L74
        capability 'Refresh' // rbn.common#L75
        capability 'HealthCheck' // rbn.common#L76
        capability 'PowerSource' // rbn.common#L77

        attribute 'healthStatus', 'enum', ['unknown', 'offline', 'online'] // rbn.common#L80
        attribute 'rtt', 'number' // rbn.common#L81
        attribute '_status_', 'string' // rbn.common#L82

        command 'configure', [[name:"✋ This button can not configure battery-powered 'sleepy' devices. Pair the device again to your hub, without deleting it!"]] // rbn.common#L87
        command 'deviceUtilities', [[name:'⚙️ Advanced administrative and diagnostic commands • Use only when troubleshooting or reconfiguring the device', type: 'ENUM', constraints: ConfigureOpts.keySet() as List<String>]] // rbn.common#L88

        command 'loadAllDefaults', [[name:'⚠️ Erases all preferences, states, scheduled jobs and child devices, then reloads the driver defaults • Use after switching drivers, or when the device was not recognised by an older version']] // rbn.common#L90
        command 'ping', [[name:'📶 Test device connectivity and measure response time • Updates the RTT attribute with round-trip time in milliseconds']] // rbn.common#L91
        command 'refresh', [[name:"🔄 Query the device for current state and update the attributes. • ⚠️ Battery-powered 'sleepy' devices may not respond!"]] // rbn.common#L92

        fingerprint profileId:'0104', endpointId:'F2', inClusters:'', outClusters:'', model:'unknown', manufacturer:'unknown', deviceJoinName: 'Zigbee device affected by Hubitat F2 bug' // rbn.common#L95

    preferences { // rbn.common#L97

        if (device) { // rbn.common#L102
            input name: 'advancedOptions', type: 'bool', title: '<b>Advanced Options</b>', description: 'The advanced options should be already automatically set in an optimal way for your device...Click on the "Save and Close" button when toggling this option!', defaultValue: false // rbn.common#L103
            if (advancedOptions == true) { // rbn.common#L104
                input name: 'healthCheckMethod', type: 'enum', title: '<b>Healthcheck Method</b>', options: HealthcheckMethodOpts.options, defaultValue: HealthcheckMethodOpts.defaultValue, required: true, description: 'Method to check device online/offline status.' // rbn.common#L105
                input name: 'healthCheckInterval', type: 'enum', title: '<b>Healthcheck Interval</b>', options: HealthcheckIntervalOpts.options, defaultValue: HealthcheckIntervalOpts.defaultValue, required: true, description: 'How often the hub will check the device health.<br>3 consecutive failures will result in status "offline"' // rbn.common#L106
                input name: 'ignoreDuplicatedZigbeeMessages', type: 'bool', title: '<b>Ignore Duplicated Zigbee Messages</b>', defaultValue: false, description: 'Ignore identical Zigbee attribute reports received within short time periods to reduce log spam and redundant processing' // rbn.common#L107
                input name: 'traceEnable', type: 'bool', title: '<b>Enable trace logging</b>', defaultValue: false, description: 'Turns on detailed extra trace logging for 30 minutes.' // rbn.common#L108
            } // rbn.common#L109
        } // rbn.common#L110
    } // rbn.common#L111
} // rbn.common#L112

@Field static final Integer IGNORE_DUPLICATED_ZIGBEE_MESSAGES_TIMER = 1000 // rbn.common#L114
@Field static final Integer DIGITAL_TIMER = 5000 // rbn.common#L115
@Field static final Integer REFRESH_TIMER = 6000 // rbn.common#L116
@Field static final Integer DEBOUNCING_TIMER = 300 // rbn.common#L117
@Field static final Integer COMMAND_TIMEOUT = 10 // rbn.common#L118
@Field static final Integer MAX_PING_MILISECONDS = 10000 // rbn.common#L119
@Field static final String  UNKNOWN = 'UNKNOWN' // rbn.common#L120
@Field static final Integer DEFAULT_MIN_REPORTING_TIME = 10 // rbn.common#L121
@Field static final Integer DEFAULT_MAX_REPORTING_TIME = 3600 // rbn.common#L122
@Field static final Integer PRESENCE_COUNT_THRESHOLD = 3 // rbn.common#L123
@Field static final int DELAY_MS = 200 // rbn.common#L124
@Field static final Integer INFO_AUTO_CLEAR_PERIOD = 60 // rbn.common#L125

@Field static final Map HealthcheckMethodOpts = [ // rbn.common#L127
    defaultValue: 1, options: [0: 'Disabled', 1: 'Activity check', 2: 'Periodic polling'] // rbn.common#L128
] // rbn.common#L129
@Field static final Map HealthcheckIntervalOpts = [ // rbn.common#L130
    defaultValue: 240, options: [2: 'Every 2 Mins', 10: 'Every 10 Mins', 30: 'Every 30 Mins', 60: 'Every 1 Hour', 240: 'Every 4 Hours', 720: 'Every 12 Hours'] // rbn.common#L131
] // rbn.common#L132

@Field static final Map ConfigureOpts = [ // rbn.common#L134
    '*** LOAD ALL DEFAULTS ***'  : [key:0, function: 'loadAllDefaults'], // rbn.common#L135
    'Configure the device'       : [key:2, function: 'configureNow'], // rbn.common#L136
    'Reset Statistics'           : [key:9, function: 'resetStatistics'], // rbn.common#L137
    'Delete All Preferences'     : [key:4, function: 'deleteAllSettings'], // rbn.common#L138
    'Delete All Current States'  : [key:5, function: 'deleteAllCurrentStates'], // rbn.common#L139
    'Delete All Scheduled Jobs'  : [key:6, function: 'deleteAllScheduledJobs'], // rbn.common#L140
    'Delete All State Variables' : [key:7, function: 'deleteAllStates'], // rbn.common#L141
    'Delete All Child Devices'   : [key:8, function: 'deleteAllChildDevices'] // rbn.common#L142
] // rbn.common#L143

public boolean isVirtual() { device.controllerType == null || device.controllerType == '' } // rbn.common#L145

public void parse(final String description) { // rbn.common#L151
    Map stateCopy = state // rbn.common#L152
    checkDriverVersion(stateCopy) // rbn.common#L153
    if (state.stats != null) { state.stats?.rxCtr= (state.stats?.rxCtr ?: 0) + 1 } else { state.stats = [:] } // rbn.common#L154
    if (state.lastRx != null) { state.lastRx?.timeStamp = unix2formattedDate(now()) } else { state.lastRx = [:] } // rbn.common#L155
    unscheduleCommandTimeoutCheck(state) // rbn.common#L156
    setHealthStatusOnline(state) // rbn.common#L157

    if (description?.startsWith('zone status')  || description?.startsWith('zone report')) { // rbn.common#L159
        logDebug "parse: zone status: $description" // rbn.common#L160
        if (this.respondsTo('customParseIasMessage')) { customParseIasMessage(description) } // rbn.common#L161
        else if (this.respondsTo('standardParseIasMessage')) { standardParseIasMessage(description) } // rbn.common#L162
        else if (this.respondsTo('parseIasMessage')) { parseIasMessage(description) } // rbn.common#L163
        else { logDebug "ignored IAS zone status (no IAS parser) description: $description" } // rbn.common#L164
        return // rbn.common#L165
    } // rbn.common#L166
    else if (description?.startsWith('enroll request')) { // rbn.common#L167
        logDebug "parse: enroll request: $description" // rbn.common#L168

        if (settings?.logEnable) { logInfo 'Sending IAS enroll response...' } // rbn.common#L170
        List<String> cmds = zigbee.enrollResponse() + zigbee.readAttribute(0x0500, 0x0000) // rbn.common#L171
        logDebug "enroll response: ${cmds}" // rbn.common#L172
        sendZigbeeCommands(cmds) // rbn.common#L173
        return // rbn.common#L174
    } // rbn.common#L175

    final Map descMap = myParseDescriptionAsMap(description) // rbn.common#L177

    if (!isChattyDeviceReport(descMap)) { logDebug "parse: descMap = ${descMap} description=${description }" } // rbn.common#L179
    if (isSpammyDeviceReport(descMap)) { return } // rbn.common#L180

    if (descMap.profileId == '0000') { // rbn.common#L182
        parseZdoClusters(descMap) // rbn.common#L183
        return // rbn.common#L184
    } // rbn.common#L185
    if (descMap.isClusterSpecific == false) { // rbn.common#L186
        parseGeneralCommandResponse(descMap) // rbn.common#L187
        return // rbn.common#L188
    } // rbn.common#L189

    if (standardAndCustomParseCluster(descMap, description)) { return } // rbn.common#L191

    switch (descMap.clusterInt as Integer) { // rbn.common#L193
        case 0x000C : // rbn.common#L194
            if (this.respondsTo('customParseAnalogInputClusterDescription')) { // rbn.common#L195
                customParseAnalogInputClusterDescription(descMap, description) // rbn.common#L196
                descMap.remove('additionalAttrs')?.each { final Map map -> customParseAnalogInputClusterDescription(descMap + map, description) } // rbn.common#L197
            } // rbn.common#L198
            break // rbn.common#L199
        case 0x0300 : // rbn.common#L200
            if (this.respondsTo('standardParseColorControlCluster')) { // rbn.common#L201
                standardParseColorControlCluster(descMap, description) // rbn.common#L202
                descMap.remove('additionalAttrs')?.each { final Map map -> standardParseColorControlCluster(descMap + map, description) } // rbn.common#L203
            } // rbn.common#L204
            break // rbn.common#L205
        default: // rbn.common#L206
            if (settings.logEnable) { // rbn.common#L207

                String clusterHex = descMap.cluster ?: descMap.clusterId ?: zigbee.convertToHexString(descMap.clusterInt as Integer, 4) // rbn.common#L209
                logWarn "parse: zigbee received <b>unknown cluster:0x${clusterHex} (${descMap.clusterInt})</b> message (${descMap})" // rbn.common#L210
            } // rbn.common#L211
            break // rbn.common#L212
    } // rbn.common#L213
} // rbn.common#L214

@Field static final Map<Integer, String> ClustersMap = [ // rbn.common#L216
    0x0000: 'Basic',             0x0001: 'Power',            0x0003: 'Identify',         0x0004: 'Groups',           0x0005: 'Scenes',       0x0006: 'OnOff',           0x0007:'onOffConfiguration',      0x0008: 'LevelControl', // rbn.common#L217
    0x000C: 'AnalogInput',       0x0012: 'MultistateInput',  0x0020: 'PollControl',      0x0102: 'WindowCovering',   0x0201: 'Thermostat',  0x0204: 'ThermostatConfig', // rbn.common#L218
    0x0400: 'Illuminance',       0x0402: 'Temperature',      0x0405: 'Humidity',         0x0406: 'Occupancy',        0x042A: 'Pm25',         0x0500: 'IAS',             0x0702: 'Metering', // rbn.common#L219
    0x0B04: 'ElectricalMeasure', 0xE001: 'E0001',            0xE002: 'E002',             0xEC03: 'EC03',             0xFC03: 'FC03',            0xFC11: 'FC11',            0xFC7E: 'AirQualityIndex', // rbn.common#L220
    0xFC80: 'FC80',              0xFC81: 'FC81',             0xFCC0: 'XiaomiFCC0',       0xED00: 'ED00' // rbn.common#L221
] // rbn.common#L222

boolean standardAndCustomParseCluster(Map descMap, final String description) { // rbn.common#L226
    Integer clusterInt = descMap.clusterInt as Integer // rbn.common#L227
    String  clusterName = ClustersMap[clusterInt] ?: UNKNOWN // rbn.common#L228

    String  clusterHex = descMap.cluster ?: descMap.clusterId ?: zigbee.convertToHexString(clusterInt, 4) // rbn.common#L230
    if (clusterName == null || clusterName == UNKNOWN) { // rbn.common#L231
        logWarn "standardAndCustomParseCluster: zigbee received <b>unknown cluster:0x${clusterHex} (${clusterInt})</b> message (${descMap})" // rbn.common#L232
        return false // rbn.common#L233
    } // rbn.common#L234
    String customParser = "customParse${clusterName}Cluster" // rbn.common#L235

    if (this.respondsTo(customParser)) { // rbn.common#L237
        this."${customParser}"(descMap) // rbn.common#L238
        descMap.remove('additionalAttrs')?.each { final Map map -> this."${customParser}"(descMap + map) } // rbn.common#L239
        return true // rbn.common#L240
    } // rbn.common#L241
    String standardParser = "standardParse${clusterName}Cluster" // rbn.common#L242

    if (this.respondsTo(standardParser)) { // rbn.common#L244
        this."${standardParser}"(descMap) // rbn.common#L245
        descMap.remove('additionalAttrs')?.each { final Map map -> this."${standardParser}"(descMap + map) } // rbn.common#L246
        return true // rbn.common#L247
    } // rbn.common#L248
    if (device?.getDataValue('model') != 'ZigUSB' && descMap.cluster != '0300') { // rbn.common#L249
        logWarn "standardAndCustomParseCluster: <b>Missing</b> ${standardParser} or ${customParser} handler for <b>cluster:0x${clusterHex} (${clusterInt})</b> message (${descMap})" // rbn.common#L250
    } // rbn.common#L251
    return false // rbn.common#L252
} // rbn.common#L253

private static void updateRxStats(final Map state) { // rbn.common#L256
    if (state.stats != null) { state.stats['rxCtr'] = (state.stats['rxCtr'] ?: 0) + 1 } else { state.stats = [:] } // rbn.common#L257
} // rbn.common#L258

public boolean isChattyDeviceReport(final Map descMap)  { // rbn.common#L260
    if (_TRACE_ALL == true) { return false } // rbn.common#L261
    if (this.respondsTo('isSpammyDPsToNotTrace')) { // rbn.common#L262
        return isSpammyDPsToNotTrace(descMap) // rbn.common#L263
    } // rbn.common#L264
    return false // rbn.common#L265
} // rbn.common#L266

public boolean isSpammyDeviceReport(final Map descMap) { // rbn.common#L268
    if (_TRACE_ALL == true) { return false } // rbn.common#L269
    if (this.respondsTo('isSpammyDPsToIgnore')) { // rbn.common#L270
        return isSpammyDPsToIgnore(descMap) // rbn.common#L271
    } // rbn.common#L272
    return false // rbn.common#L273
} // rbn.common#L274

@Field static final Map<Integer, String> ZdoClusterEnum = [ // rbn.common#L276
    0x0002: 'Node Descriptor Request',  0x0005: 'Active Endpoints Request',   0x0006: 'Match Descriptor Request',  0x0022: 'Unbind Request',  0x0013: 'Device announce', 0x0034: 'Management Leave Request', // rbn.common#L277
    0x8002: 'Node Descriptor Response', 0x8004: 'Simple Descriptor Response', 0x8005: 'Active Endpoints Response', 0x801D: 'Extended Simple Descriptor Response', 0x801E: 'Extended Active Endpoint Response', // rbn.common#L278
    0x8021: 'Bind Response',            0x8022: 'Unbind Response',            0x8023: 'Bind Register Response',    0x8034: 'Management Leave Response' // rbn.common#L279
] // rbn.common#L280

private void parseZdoClusters(final Map descMap) { // rbn.common#L283
    if (state.stats == null) { state.stats = [:] } // rbn.common#L284
    final Integer clusterId = descMap.clusterInt as Integer // rbn.common#L285
    final String clusterName = ZdoClusterEnum[clusterId] ?: "UNKNOWN_CLUSTER (0x${descMap.clusterId})" // rbn.common#L286
    final String statusHex = ((List)descMap.data)[1] // rbn.common#L287
    final Integer statusCode = hexStrToUnsignedInt(statusHex) // rbn.common#L288
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${statusHex}" // rbn.common#L289
    final String clusterInfo = "${device.displayName} Received ZDO ${clusterName} (0x${descMap.clusterId}) status ${statusName}" // rbn.common#L290
    List<String> cmds = [] // rbn.common#L291
    switch (clusterId) { // rbn.common#L292
        case 0x0005 : // rbn.common#L293
            state.stats['activeEpRqCtr'] = (state.stats['activeEpRqCtr'] ?: 0) + 1 // rbn.common#L294
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, data:${descMap.data})" } // rbn.common#L295

            cmds += ["he raw ${device.deviceNetworkId} 0 0 0x8005 {00 00 00 00 01 01} {0x0000}"] // rbn.common#L297
            sendZigbeeCommands(cmds) // rbn.common#L298
            break // rbn.common#L299
        case 0x0006 : // rbn.common#L300
            state.stats['matchDescCtr'] = (state.stats['matchDescCtr'] ?: 0) + 1 // rbn.common#L301
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Input cluster count:${descMap.data[5]} Input cluster: 0x${descMap.data[7] + descMap.data[6]})" } // rbn.common#L302
            cmds += ["he raw ${device.deviceNetworkId} 0 0 0x8006 {00 00 00 00 00} {0x0000}"] // rbn.common#L303
            sendZigbeeCommands(cmds) // rbn.common#L304
            break // rbn.common#L305
        case 0x0013 : // rbn.common#L306
            state.stats['rejoinCtr'] = (state.stats['rejoinCtr'] ?: 0) + 1 // rbn.common#L307
            if (settings?.logEnable) { log.debug "${clusterInfo}, rejoinCtr= ${state.stats['rejoinCtr']}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Device network ID: ${descMap.data[2] + descMap.data[1]}, Capability Information: ${descMap.data[11]})" } // rbn.common#L308
            break // rbn.common#L309
        case 0x8004 : // rbn.common#L310
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, status:${descMap.data[1]}, lenght:${hubitat.helper.HexUtils.hexStringToInt(descMap.data[4])}" } // rbn.common#L311
            if (this.respondsTo('parseSimpleDescriptorResponse')) { parseSimpleDescriptorResponse(descMap) } // rbn.common#L312
            break // rbn.common#L313
        case 0x8005 : // rbn.common#L314
            String endpointCount = descMap.data[4] // rbn.common#L315
            String endpointList = descMap.data[5] // rbn.common#L316
            if (settings?.logEnable) { log.debug "${clusterInfo}, (endpoint response) endpointCount = ${endpointCount}  endpointList = ${endpointList}" } // rbn.common#L317
            break // rbn.common#L318
        case 0x8021 : // rbn.common#L319
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Status: ${descMap.data[1] == '00' ? 'Success' : '<b>Failure</b>'})" } // rbn.common#L320
            break // rbn.common#L321
        case 0x0002 : // rbn.common#L322
        case 0x0036 : // rbn.common#L323
        case 0x8022 : // rbn.common#L324
        case 0x8034 : // rbn.common#L325
            if (settings?.logEnable) { log.debug "${device.displayName} Unprocessed ZDO command: cluster=${descMap.clusterId} command=${descMap.command} attrId=${descMap.attrId} value=${descMap.value} data=${descMap.data}" } // rbn.common#L326
            break // rbn.common#L327
        default : // rbn.common#L328
            if (settings?.logEnable) { log.warn "${device.displayName} Unprocessed ZDO command: cluster=${descMap.clusterId} command=${descMap.command} attrId=${descMap.attrId} value=${descMap.value} data=${descMap.data}" } // rbn.common#L329
            break // rbn.common#L330
    } // rbn.common#L331
    if (this.respondsTo('customParseZdoClusters')) { customParseZdoClusters(descMap) } // rbn.common#L332
} // rbn.common#L333

private void parseGeneralCommandResponse(final Map descMap) { // rbn.common#L336
    final int commandId = hexStrToUnsignedInt(descMap.command) // rbn.common#L337
    switch (commandId) { // rbn.common#L338
        case 0x01: parseReadAttributeResponse(descMap); break // rbn.common#L339
        case 0x04: parseWriteAttributeResponse(descMap); break // rbn.common#L340
        case 0x07: parseConfigureResponse(descMap); break // rbn.common#L341
        case 0x09: parseReadReportingConfigResponse(descMap); break // rbn.common#L342
        case 0x0B: parseDefaultCommandResponse(descMap); break // rbn.common#L343
        default: // rbn.common#L344
            final String commandName = ZigbeeGeneralCommandEnum[commandId] ?: "UNKNOWN_COMMAND (0x${descMap.command})" // rbn.common#L345
            final String clusterName = clusterLookup(descMap.clusterInt) // rbn.common#L346
            final String status = descMap.data in List ? ((List)descMap.data).last() : descMap.data // rbn.common#L347
            final int statusCode = hexStrToUnsignedInt(status) // rbn.common#L348
            final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${status}" // rbn.common#L349
            if (statusCode > 0x00) { // rbn.common#L350
                log.warn "zigbee ${commandName} ${clusterName} error: ${statusName}" // rbn.common#L351
            } else if (settings.logEnable) { // rbn.common#L352
                log.trace "zigbee ${commandName} ${clusterName}: ${descMap.data}" // rbn.common#L353
            } // rbn.common#L354
            break // rbn.common#L355
    } // rbn.common#L356
} // rbn.common#L357

private void parseReadAttributeResponse(final Map descMap) { // rbn.common#L360
    final List<String> data = descMap.data as List<String> // rbn.common#L361
    final String attribute = data[1] + data[0] // rbn.common#L362
    final int statusCode = hexStrToUnsignedInt(data[2]) // rbn.common#L363
    final String status = ZigbeeStatusEnum[statusCode] ?: "0x${data}" // rbn.common#L364
    if (statusCode > 0x00) { // rbn.common#L365
        logWarn "zigbee read ${clusterLookup(descMap.clusterInt)} attribute 0x${attribute} error: ${status}" // rbn.common#L366
    } // rbn.common#L367
    else { // rbn.common#L368
        logDebug "zigbee read ${clusterLookup(descMap.clusterInt)} attribute 0x${attribute} response: ${status} ${data}" // rbn.common#L369
    } // rbn.common#L370
} // rbn.common#L371

private void parseWriteAttributeResponse(final Map descMap) { // rbn.common#L374
    final String data = descMap.data in List ? ((List)descMap.data).first() : descMap.data // rbn.common#L375
    final int statusCode = hexStrToUnsignedInt(data) // rbn.common#L376
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${data}" // rbn.common#L377
    if (statusCode > 0x00) { // rbn.common#L378
        logWarn "zigbee response write ${clusterLookup(descMap.clusterInt)} attribute error: ${statusName}" // rbn.common#L379
    } // rbn.common#L380
    else { // rbn.common#L381
        logDebug "zigbee response write ${clusterLookup(descMap.clusterInt)} attribute response: ${statusName}" // rbn.common#L382
    } // rbn.common#L383
} // rbn.common#L384

private void parseConfigureResponse(final Map descMap) { // rbn.common#L387

    final String status = ((List)descMap.data).first() // rbn.common#L389
    final int statusCode = hexStrToUnsignedInt(status) // rbn.common#L390
    if (statusCode == 0x00 && settings.enableReporting != false) { // rbn.common#L391
        state.reportingEnabled = true // rbn.common#L392
    } // rbn.common#L393
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${status}" // rbn.common#L394
    if (statusCode > 0x00) { // rbn.common#L395
        log.warn "zigbee configure reporting error: ${statusName} ${descMap.data}" // rbn.common#L396
    } else { // rbn.common#L397
        logDebug "zigbee configure reporting response: ${statusName} ${descMap.data}" // rbn.common#L398
    } // rbn.common#L399
} // rbn.common#L400

private void parseReadReportingConfigResponse(final Map descMap) { // rbn.common#L403
    int status = zigbee.convertHexToInt(descMap.data[0]) // rbn.common#L404

    if (status == 0) { // rbn.common#L406

        int min = zigbee.convertHexToInt(descMap.data[6]) * 256 + zigbee.convertHexToInt(descMap.data[5]) // rbn.common#L408
        int max = zigbee.convertHexToInt(descMap.data[8] + descMap.data[7]) // rbn.common#L409
        int delta = 0 // rbn.common#L410
        if (descMap.data.size() >= 11) { // rbn.common#L411
            delta = zigbee.convertHexToInt(descMap.data[10] + descMap.data[9]) // rbn.common#L412
        } // rbn.common#L413
        else if (descMap.data.size() == 10) { // rbn.common#L414
            delta = zigbee.convertHexToInt(descMap.data[9]) // rbn.common#L415
        } // rbn.common#L416
        else { // rbn.common#L417
            logTrace "descMap.data.size = ${descMap.data.size()}" // rbn.common#L418
        } // rbn.common#L419
        logDebug "Received Read Reporting Configuration Response (0x09) for cluster:${descMap.clusterId} attribute:${descMap.data[3] + descMap.data[2]}, data=${descMap.data} (Status: ${descMap.data[0] == '00' ? 'Success' : '<b>Failure</b>'}) min=${min} max=${max} delta=${delta}" // rbn.common#L420
    } // rbn.common#L421
    else { // rbn.common#L422
        logWarn "<b>Not Found (0x8b)</b> Read Reporting Configuration Response for cluster:${descMap.clusterId} attribute:${descMap.data[3] + descMap.data[2]}, data=${descMap.data} (Status: ${descMap.data[0] == '00' ? 'Success' : '<b>Failure</b>'})" // rbn.common#L423
    } // rbn.common#L424
} // rbn.common#L425

private Boolean executeCustomHandler(String handlerName, Object handlerArgs) { // rbn.common#L427
    if (!this.respondsTo(handlerName)) { // rbn.common#L428
        logTrace "executeCustomHandler: function <b>${handlerName}</b> not found" // rbn.common#L429
        return false // rbn.common#L430
    } // rbn.common#L431

    Boolean result = false // rbn.common#L433
    try { // rbn.common#L434
        result = "$handlerName"(handlerArgs) // rbn.common#L435
    } // rbn.common#L436
    catch (e) { // rbn.common#L437
        logWarn "executeCustomHandler: Exception '${e}'caught while processing <b>$handlerName</b>(<b>$handlerArgs</b>) (val=${fncmd}))" // rbn.common#L438
        return false // rbn.common#L439
    } // rbn.common#L440

    return result // rbn.common#L442
} // rbn.common#L443

private void parseDefaultCommandResponse(final Map descMap) { // rbn.common#L446
    final List<String> data = descMap.data as List<String> // rbn.common#L447
    final String commandId = data[0] // rbn.common#L448
    final int statusCode = hexStrToUnsignedInt(data[1]) // rbn.common#L449
    final String status = ZigbeeStatusEnum[statusCode] ?: "0x${data[1]}" // rbn.common#L450
    if (statusCode > 0x00) { // rbn.common#L451
        logWarn "zigbee ${clusterLookup(descMap.clusterInt)} command 0x${commandId} error: ${status}" // rbn.common#L452
    } else { // rbn.common#L453
        logDebug "zigbee ${clusterLookup(descMap.clusterInt)} command 0x${commandId} response: ${status}" // rbn.common#L454

        if (this.respondsTo('customParseDefaultCommandResponse')) { // rbn.common#L456
            customParseDefaultCommandResponse(descMap) // rbn.common#L457
        } // rbn.common#L458
    } // rbn.common#L459
} // rbn.common#L460

@Field static final int ATTRIBUTE_READING_INFO_SET = 0x0000 // rbn.common#L463
@Field static final int FIRMWARE_VERSION_ID = 0x4000 // rbn.common#L464
@Field static final int PING_ATTR_ID = 0x01 // rbn.common#L465

@Field static final Map<Integer, String> ZigbeeStatusEnum = [ // rbn.common#L467
    0x00: 'Success', 0x01: 'Failure', 0x02: 'Not Authorized', 0x80: 'Malformed Command', 0x81: 'Unsupported COMMAND', 0x85: 'Invalid Field', 0x86: 'Unsupported Attribute', 0x87: 'Invalid Value', 0x88: 'Read Only', // rbn.common#L468
    0x89: 'Insufficient Space', 0x8A: 'Duplicate Exists', 0x8B: 'Not Found', 0x8C: 'Unreportable Attribute', 0x8D: 'Invalid Data Type', 0x8E: 'Invalid Selector', 0x94: 'Time out', 0x9A: 'Notification Pending', 0xC3: 'Unsupported Cluster' // rbn.common#L469
] // rbn.common#L470

@Field static final Map<Integer, String> ZigbeeGeneralCommandEnum = [ // rbn.common#L472
    0x00: 'Read Attributes', 0x01: 'Read Attributes Response', 0x02: 'Write Attributes', 0x03: 'Write Attributes Undivided', 0x04: 'Write Attributes Response', 0x05: 'Write Attributes No Response', 0x06: 'Configure Reporting', // rbn.common#L473
    0x07: 'Configure Reporting Response', 0x08: 'Read Reporting Configuration', 0x09: 'Read Reporting Configuration Response', 0x0A: 'Report Attributes', 0x0B: 'Default Response', 0x0C: 'Discover Attributes', 0x0D: 'Discover Attributes Response', // rbn.common#L474
    0x0E: 'Read Attributes Structured', 0x0F: 'Write Attributes Structured', 0x10: 'Write Attributes Structured Response', 0x11: 'Discover Commands Received', 0x12: 'Discover Commands Received Response', 0x13: 'Discover Commands Generated', // rbn.common#L475
    0x14: 'Discover Commands Generated Response', 0x15: 'Discover Attributes Extended', 0x16: 'Discover Attributes Extended Response' // rbn.common#L476
] // rbn.common#L477

@Field static final int ROLLING_AVERAGE_N = 10 // rbn.common#L479
private BigDecimal approxRollingAverage(BigDecimal avgPar, BigDecimal newSample) { // rbn.common#L480
    BigDecimal avg = avgPar // rbn.common#L481
    if (avg == null || avg == 0) { avg = newSample } // rbn.common#L482
    avg -= avg / ROLLING_AVERAGE_N // rbn.common#L483
    avg += newSample / ROLLING_AVERAGE_N // rbn.common#L484
    return avg // rbn.common#L485
} // rbn.common#L486

private void handlePingResponse() { // rbn.common#L488
    Long now = new Date().getTime() // rbn.common#L489
    if (state.lastRx == null) { state.lastRx = [:] } // rbn.common#L490
    state.lastRx['checkInTime'] = now // rbn.common#L491

    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: '0').toInteger() // rbn.common#L493
    if (timeRunning > 0 && timeRunning < MAX_PING_MILISECONDS) { // rbn.common#L494
        state.stats['pingsOK'] = (state.stats['pingsOK'] ?: 0) + 1 // rbn.common#L495
        if (timeRunning < safeToInt((state.stats['pingsMin'] ?: '9999'))) { state.stats['pingsMin'] = timeRunning } // rbn.common#L496
        if (timeRunning > safeToInt((state.stats['pingsMax'] ?: '0')))   { state.stats['pingsMax'] = timeRunning } // rbn.common#L497
        state.stats['pingsAvg'] = approxRollingAverage(safeToDouble(state.stats['pingsAvg']), safeToDouble(timeRunning)) as int // rbn.common#L498
        sendRttEvent() // rbn.common#L499
    } // rbn.common#L500
    else { // rbn.common#L501
        logWarn "unexpected ping timeRunning=${timeRunning} " // rbn.common#L502
    } // rbn.common#L503
    state.states['isPing'] = false // rbn.common#L504
} // rbn.common#L505

@Field static final Map powerSourceOpts =  [ defaultValue: 0, options: [0: 'unknown', 1: 'mains', 2: 'mains', 3: 'battery', 4: 'dc', 5: 'emergency mains', 6: 'emergency mains']] // rbn.common#L512

private void standardParseBasicCluster(final Map descMap) { // rbn.common#L515
    Long now = new Date().getTime() // rbn.common#L516
    if (state.lastRx == null) { state.lastRx = [:] } // rbn.common#L517
    state.lastRx['checkInTime'] = now // rbn.common#L518
    boolean isPing = state.states?.isPing ?: false // rbn.common#L519
    switch (descMap.attrInt as Integer) { // rbn.common#L520
        case 0x0000: // rbn.common#L521
            logDebug "Basic cluster: ZCLVersion = ${descMap?.value}" // rbn.common#L522
            break // rbn.common#L523
        case PING_ATTR_ID: // rbn.common#L524
            if (isPing) { // rbn.common#L525
                handlePingResponse() // rbn.common#L526
            } // rbn.common#L527
            else { // rbn.common#L528
                logTrace "Tuya check-in message (attribute ${descMap.attrId} reported: ${descMap.value})" // rbn.common#L529
            } // rbn.common#L530
            break // rbn.common#L531
        case 0x0004: // rbn.common#L532
            logDebug "received device manufacturer ${descMap?.value}" // rbn.common#L533

            String manufacturer = device.getDataValue('manufacturer') // rbn.common#L535
            if ((manufacturer == null || manufacturer == 'unknown') && (descMap?.value != null)) { // rbn.common#L536
                logWarn "updating device manufacturer from ${manufacturer} to ${descMap?.value}" // rbn.common#L537
                device.updateDataValue('manufacturer', descMap?.value) // rbn.common#L538
            } // rbn.common#L539
            break // rbn.common#L540
        case 0x0005: // rbn.common#L541
            if (isPing) { // rbn.common#L542
                handlePingResponse() // rbn.common#L543
            } // rbn.common#L544
            else { // rbn.common#L545
                logDebug "received device model ${descMap?.value}" // rbn.common#L546

                String model = device.getDataValue('model') // rbn.common#L548
                if ((model == null || model == 'unknown') && (descMap?.value != null)) { // rbn.common#L549
                    logWarn "updating device model from ${model} to ${descMap?.value}" // rbn.common#L550
                    device.updateDataValue('model', descMap?.value) // rbn.common#L551
                } // rbn.common#L552
            } // rbn.common#L553
            break // rbn.common#L554
        case 0x0007: // rbn.common#L555
            String powerSourceReported = powerSourceOpts.options[descMap?.value as int] // rbn.common#L556
            logDebug "received Power source <b>${powerSourceReported}</b> (${descMap?.value})" // rbn.common#L557
            String currentPowerSource = device.getDataValue('powerSource') // rbn.common#L558
            if (currentPowerSource == null || currentPowerSource == 'unknown') { // rbn.common#L559
                logInfo "updating device powerSource from ${currentPowerSource} to ${powerSourceReported}" // rbn.common#L560
                sendEvent(name: 'powerSource', value: powerSourceReported, type: 'physical') // rbn.common#L561
            } // rbn.common#L562
            break // rbn.common#L563
        case 0xFFDF: // rbn.common#L564
            logDebug "Tuya check-in (Cluster Revision=${descMap?.value})" // rbn.common#L565
            break // rbn.common#L566
        case 0xFFE2: // rbn.common#L567
            logDebug "Tuya check-in (AppVersion=${descMap?.value})" // rbn.common#L568
            break // rbn.common#L569
        case [0xFFE0, 0xFFE1, 0xFFE3, 0xFFE4] : // rbn.common#L570
            logTrace "Tuya attribute ${descMap?.attrId} value=${descMap?.value}" // rbn.common#L571
            break // rbn.common#L572
        case 0xFFFE: // rbn.common#L573
            logTrace "Tuya attributeReportingStatus (attribute FFFE) value=${descMap?.value}" // rbn.common#L574
            break // rbn.common#L575
        case FIRMWARE_VERSION_ID: // rbn.common#L576
            final String version = descMap.value ?: 'unknown' // rbn.common#L577
            logInfo "device firmware version is ${version}" // rbn.common#L578
            updateDataValue('softwareBuild', version) // rbn.common#L579
            break // rbn.common#L580
        default: // rbn.common#L581
            logDebug "zigbee received unknown Basic cluster attribute 0x${descMap.attrId} (value ${descMap.value})" // rbn.common#L582
            break // rbn.common#L583
    } // rbn.common#L584
} // rbn.common#L585

private void standardParsePollControlCluster(final Map descMap) { // rbn.common#L587
    switch (descMap.attrInt as Integer) { // rbn.common#L588
        case 0x0000: logDebug "PollControl cluster: CheckInInterval = ${descMap?.value}" ; break // rbn.common#L589
        case 0x0001: logDebug "PollControl cluster: LongPollInterval = ${descMap?.value}" ; break // rbn.common#L590
        case 0x0002: logDebug "PollControl cluster: ShortPollInterval = ${descMap?.value}" ; break // rbn.common#L591
        case 0x0003: logDebug "PollControl cluster: FastPollTimeout = ${descMap?.value}" ; break // rbn.common#L592
        case 0x0004: logDebug "PollControl cluster: CheckInIntervalMin = ${descMap?.value}" ; break // rbn.common#L593
        case 0x0005: logDebug "PollControl cluster: LongPollIntervalMin = ${descMap?.value}" ; break // rbn.common#L594
        case 0x0006: logDebug "PollControl cluster: FastPollTimeoutMax = ${descMap?.value}" ; break // rbn.common#L595
        default: logDebug "zigbee received unknown PollControl cluster attribute 0x${descMap.attrId} (value ${descMap.value})" ; break // rbn.common#L596
    } // rbn.common#L597
} // rbn.common#L598

public void clearIsDigital()        { state.states['isDigital'] = false } // rbn.common#L600
void switchDebouncingClear() { state.states['debounce']  = false } // rbn.common#L601
void isRefreshRequestClear() { state.states['isRefresh'] = false } // rbn.common#L602

Map myParseDescriptionAsMap(String description) { // rbn.common#L604
    Map descMap = [:] // rbn.common#L605
    try { // rbn.common#L606
        descMap = zigbee.parseDescriptionAsMap(description) // rbn.common#L607
    } // rbn.common#L608
    catch (e1) { // rbn.common#L609
        logWarn "exception ${e1} caught while parseDescriptionAsMap <b>myParseDescriptionAsMap</b> description:  ${description}" // rbn.common#L610

        descMap = [:] // rbn.common#L612
        try { // rbn.common#L613
            descMap += description.replaceAll('\\[|\\]', '').split(',').collectEntries { entry -> // rbn.common#L614
                List<String> pair = entry.split(':') // rbn.common#L615
                [(pair.first().trim()): pair.last().trim()] // rbn.common#L616
            } // rbn.common#L617
        } // rbn.common#L618
        catch (e2) { // rbn.common#L619
            logWarn "exception ${e2} caught while parsing using an alternative method <b>myParseDescriptionAsMap</b> description:  ${description}" // rbn.common#L620
            return [:] // rbn.common#L621
        } // rbn.common#L622
        logDebug "alternative method parsing success: descMap=${descMap}" // rbn.common#L623
    } // rbn.common#L624
    return descMap // rbn.common#L625
} // rbn.common#L626

public String intTo16bitUnsignedHex(int value) { // rbn.common#L628
    String hexStr = zigbee.convertToHexString(value.toInteger(), 4) // rbn.common#L629
    return new String(hexStr.substring(2, 4) + hexStr.substring(0, 2)) // rbn.common#L630
} // rbn.common#L631

public String intTo8bitUnsignedHex(int value) { // rbn.common#L633
    return zigbee.convertToHexString(value.toInteger(), 2) // rbn.common#L634
} // rbn.common#L635

public void aqaraBlackMagic() { // rbn.common#L637
    List<String> cmds = [] // rbn.common#L638
    if (this.respondsTo('customAqaraBlackMagic')) { // rbn.common#L639
        cmds = customAqaraBlackMagic() // rbn.common#L640
    } // rbn.common#L641
    if (cmds != null && !cmds.isEmpty()) { // rbn.common#L642
        logDebug 'sending aqaraBlackMagic()' // rbn.common#L643
        sendZigbeeCommands(cmds) // rbn.common#L644
        return // rbn.common#L645
    } // rbn.common#L646
    logDebug 'aqaraBlackMagic() was SKIPPED' // rbn.common#L647
} // rbn.common#L648

public List<String> initializeDevice() { // rbn.common#L651
    List<String> cmds = [] // rbn.common#L652
    logInfo 'initializeDevice...' // rbn.common#L653
    if (this.respondsTo('customInitializeDevice')) { // rbn.common#L654
        List<String> customCmds = customInitializeDevice() // rbn.common#L655
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // rbn.common#L656
    } // rbn.common#L657
    else { logDebug 'no customInitializeDevice method defined' } // rbn.common#L658
    logDebug "initializeDevice(): cmds=${cmds}" // rbn.common#L659
    return cmds // rbn.common#L660
} // rbn.common#L661

public List<String> configureDevice() { // rbn.common#L664
    List<String> cmds = [] // rbn.common#L665
    logInfo 'configureDevice...' // rbn.common#L666
    if (this.respondsTo('customConfigureDevice')) { // rbn.common#L667
        List<String> customCmds = customConfigureDevice() // rbn.common#L668
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // rbn.common#L669
    } // rbn.common#L670
    else { logDebug 'no customConfigureDevice method defined' } // rbn.common#L671

    logDebug "configureDevice(): cmds=${cmds}" // rbn.common#L673
    return cmds // rbn.common#L674
} // rbn.common#L675

List<String> customHandlers(final List customHandlersList) { // rbn.common#L683
    List<String> cmds = [] // rbn.common#L684
    if (customHandlersList != null && !customHandlersList.isEmpty()) { // rbn.common#L685
        customHandlersList.each { handler -> // rbn.common#L686
            if (this.respondsTo(handler)) { // rbn.common#L687
                List<String> customCmds = this."${handler}"() // rbn.common#L688
                if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // rbn.common#L689
            } // rbn.common#L690
        } // rbn.common#L691
    } // rbn.common#L692
    return cmds // rbn.common#L693
} // rbn.common#L694

public void refresh() { // rbn.common#L696
    logDebug "refresh()... DEVICE_TYPE is ${DEVICE_TYPE} model=${device.getDataValue('model')} manufacturer=${device.getDataValue('manufacturer')}" // rbn.common#L697
    checkDriverVersion(state) // rbn.common#L698
    List<String> cmds = [], customCmds = [] // rbn.common#L699
    if (this.respondsTo('customRefresh')) { // rbn.common#L700
        customCmds = customRefresh() // rbn.common#L701
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } else { logDebug 'no customRefresh method defined' } // rbn.common#L702
    } // rbn.common#L703
    else { // rbn.common#L704
        customCmds = customHandlers(['onOffRefresh', 'groupsRefresh', 'batteryRefresh', 'levelRefresh', 'temperatureRefresh', 'humidityRefresh', 'illuminanceRefresh']) // rbn.common#L705
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } else { logDebug 'no libraries refresh() defined' } // rbn.common#L706
    } // rbn.common#L707
    if (cmds != null && !cmds.isEmpty()) { // rbn.common#L708
        logDebug "refresh() cmds=${cmds}" // rbn.common#L709
        setRefreshRequest() // rbn.common#L710
        sendZigbeeCommands(cmds) // rbn.common#L711
    } // rbn.common#L712
    else { // rbn.common#L713
        logDebug "no refresh() commands defined for device type ${DEVICE_TYPE}" // rbn.common#L714
    } // rbn.common#L715
} // rbn.common#L716

public void setRefreshRequest()   { if (state.states == null) { state.states = [:] } ; state.states['isRefresh'] = true; runInMillis(REFRESH_TIMER, 'clearRefreshRequest', [overwrite: true]) } // rbn.common#L718
public void clearRefreshRequest() { if (state.states == null) { state.states = [:] } ; state.states['isRefresh'] = false } // rbn.common#L719
public void clearInfoEvent()      { sendInfoEvent('clear') } // rbn.common#L720

public void sendInfoEvent(String info=null) { // rbn.common#L722
    if (info == null || info == 'clear') { // rbn.common#L723
        logDebug 'clearing the Status event' // rbn.common#L724
        sendEvent(name: '_status_', value: 'clear', type: 'digital') // rbn.common#L725
    } // rbn.common#L726
    else { // rbn.common#L727
        logInfo "${info}" // rbn.common#L728
        sendEvent(name: '_status_', value: info, type: 'digital') // rbn.common#L729
        runIn(INFO_AUTO_CLEAR_PERIOD, 'clearInfoEvent') // rbn.common#L730
    } // rbn.common#L731
} // rbn.common#L732

public void ping() { // rbn.common#L734
    if (state.lastTx == null ) { state.lastTx = [:] } ; state.lastTx['pingTime'] = new Date().getTime() // rbn.common#L735
    if (state.states == null ) { state.states = [:] } ; state.states['isPing'] = true // rbn.common#L736
    scheduleCommandTimeoutCheck() // rbn.common#L737
    int  pingAttr = (device.getDataValue('manufacturer') == 'SONOFF') ? 0x05 : PING_ATTR_ID // rbn.common#L738
    if (isVirtual()) { runInMillis(10, 'virtualPong') } // rbn.common#L739
    else if (device.getDataValue('manufacturer') == 'Aqara') { // rbn.common#L740
        logDebug 'Aqara device ping...' // rbn.common#L741
        sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, pingAttr, [destEndpoint: 0x01], 0) ) // rbn.common#L742
    } // rbn.common#L743
    else { sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, pingAttr, [:], 0) ) } // rbn.common#L744
    logDebug 'ping...' // rbn.common#L745
} // rbn.common#L746

private void virtualPong() { // rbn.common#L748
    logDebug 'virtualPing: pong!' // rbn.common#L749
    Long now = new Date().getTime() // rbn.common#L750
    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: '0').toInteger() // rbn.common#L751
    if (timeRunning > 0 && timeRunning < MAX_PING_MILISECONDS) { // rbn.common#L752
        state.stats['pingsOK'] = (state.stats['pingsOK'] ?: 0) + 1 // rbn.common#L753
        if (timeRunning < safeToInt((state.stats['pingsMin'] ?: '9999'))) { state.stats['pingsMin'] = timeRunning } // rbn.common#L754
        if (timeRunning > safeToInt((state.stats['pingsMax'] ?: '0')))   { state.stats['pingsMax'] = timeRunning } // rbn.common#L755
        state.stats['pingsAvg'] = approxRollingAverage(safeToDouble(state.stats['pingsAvg']), safeToDouble(timeRunning)) as int // rbn.common#L756
        sendRttEvent() // rbn.common#L757
    } // rbn.common#L758
    else { // rbn.common#L759
        logWarn "unexpected ping timeRunning=${timeRunning} " // rbn.common#L760
    } // rbn.common#L761
    state.states['isPing'] = false // rbn.common#L762
    unscheduleCommandTimeoutCheck(state) // rbn.common#L763
} // rbn.common#L764

public void sendRttEvent( String value=null) { // rbn.common#L766
    Long now = new Date().getTime() // rbn.common#L767
    if (state.lastTx == null ) { state.lastTx = [:] } // rbn.common#L768
    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: now).toInteger() // rbn.common#L769
    String descriptionText = "Round-trip time is ${timeRunning} ms (min=${state.stats['pingsMin']} max=${state.stats['pingsMax']} average=${state.stats['pingsAvg']})" // rbn.common#L770
    if (value == null) { // rbn.common#L771
        logInfo "${descriptionText}" // rbn.common#L772
        sendEvent(name: 'rtt', value: timeRunning, descriptionText: descriptionText, unit: 'ms', type: 'physical') // rbn.common#L773
    } // rbn.common#L774
    else { // rbn.common#L775
        descriptionText = "Round-trip time : ${value}" // rbn.common#L776
        logInfo "${descriptionText}" // rbn.common#L777
        sendEvent(name: 'rtt', value: value, descriptionText: descriptionText, type: 'physical') // rbn.common#L778
    } // rbn.common#L779
} // rbn.common#L780

private String clusterLookup(final Object cluster) { // rbn.common#L782
    if (cluster != null) { // rbn.common#L783
        return zigbee.clusterLookup(cluster.toInteger()) ?: "private cluster 0x${intToHexStr(cluster.toInteger())}" // rbn.common#L784
    } // rbn.common#L785
    logWarn 'cluster is NULL!' // rbn.common#L786
    return 'NULL' // rbn.common#L787
} // rbn.common#L788

private void scheduleCommandTimeoutCheck(int delay = COMMAND_TIMEOUT) { // rbn.common#L790
    if (state.states == null) { state.states = [:] } // rbn.common#L791
    state.states['isTimeoutCheck'] = true // rbn.common#L792
    runIn(delay, 'deviceCommandTimeout') // rbn.common#L793
} // rbn.common#L794

void unscheduleCommandTimeoutCheck(final Map state) { // rbn.common#L797
    if (state.states == null) { state.states = [:] } // rbn.common#L798
    if (state.states['isTimeoutCheck'] == true) { // rbn.common#L799
        state.states['isTimeoutCheck'] = false // rbn.common#L800
        unschedule('deviceCommandTimeout') // rbn.common#L801
    } // rbn.common#L802
} // rbn.common#L803

void deviceCommandTimeout() { // rbn.common#L805
    logWarn 'no response received (sleepy device or offline?)' // rbn.common#L806
    sendRttEvent('timeout') // rbn.common#L807
    state.stats['pingsFail'] = (state.stats['pingsFail'] ?: 0) + 1 // rbn.common#L808
    if (state.health?.isHealthCheck == true) { // rbn.common#L809
        logWarn 'device health check failed!' // rbn.common#L810
        state.health?.checkCtr3 = (state.health?.checkCtr3 ?: 0 ) + 1 // rbn.common#L811
        if (state.health?.checkCtr3 >= PRESENCE_COUNT_THRESHOLD) { // rbn.common#L812
            if ((device.currentValue('healthStatus') ?: 'unknown') != 'offline' ) { // rbn.common#L813
                sendHealthStatusEvent('offline') // rbn.common#L814
            } // rbn.common#L815
        } // rbn.common#L816
        state.health['isHealthCheck'] = false // rbn.common#L817
    } // rbn.common#L818
} // rbn.common#L819

private void scheduleDeviceHealthCheck(final int intervalMins, final int healthMethod) { // rbn.common#L821
    if (healthMethod == 1 || healthMethod == 2)  { // rbn.common#L822
        String cron = getCron( intervalMins * 60 ) // rbn.common#L823
        schedule(cron, 'deviceHealthCheck') // rbn.common#L824
        logDebug "deviceHealthCheck is scheduled every ${intervalMins} minutes" // rbn.common#L825
    } // rbn.common#L826
    else { // rbn.common#L827
        logWarn 'deviceHealthCheck is not scheduled!' // rbn.common#L828
        unschedule('deviceHealthCheck') // rbn.common#L829
    } // rbn.common#L830
} // rbn.common#L831

private void unScheduleDeviceHealthCheck() { // rbn.common#L833
    unschedule('deviceHealthCheck') // rbn.common#L834
    device.deleteCurrentState('healthStatus') // rbn.common#L835
    logWarn 'device health check is disabled!' // rbn.common#L836
} // rbn.common#L837

private void setHealthStatusOnline(Map state) { // rbn.common#L840
    if (state.health == null) { state.health = [:] } // rbn.common#L841
    state.health['checkCtr3']  = 0 // rbn.common#L842
    if (!((device.currentValue('healthStatus') ?: 'unknown') in ['online'])) { // rbn.common#L843
        sendHealthStatusEvent('online') // rbn.common#L844
        logInfo 'is now online!' // rbn.common#L845
    } // rbn.common#L846
} // rbn.common#L847

private void deviceHealthCheck() { // rbn.common#L849
    checkDriverVersion(state) // rbn.common#L850
    if (state.health == null) { state.health = [:] } // rbn.common#L851
    int ctr = state.health['checkCtr3'] ?: 0 // rbn.common#L852
    if (ctr  >= PRESENCE_COUNT_THRESHOLD) { // rbn.common#L853
        if ((device.currentValue('healthStatus') ?: 'unknown') != 'offline' ) { // rbn.common#L854
            logWarn 'not present!' // rbn.common#L855
            sendHealthStatusEvent('offline') // rbn.common#L856
        } // rbn.common#L857
    } // rbn.common#L858
    else { // rbn.common#L859
        logDebug "deviceHealthCheck - online (notPresentCounter=${(ctr + 1)})" // rbn.common#L860
    } // rbn.common#L861
    state.health['checkCtr3'] = ctr + 1 // rbn.common#L862

    if (settings?.healthCheckMethod as int == 2) { // rbn.common#L864
        state.health['isHealthCheck'] = true // rbn.common#L865
        ping() // rbn.common#L866
    } // rbn.common#L867
} // rbn.common#L868

private void sendHealthStatusEvent(final String value) { // rbn.common#L870
    String descriptionText = "healthStatus changed to ${value}" // rbn.common#L871
    sendEvent(name: 'healthStatus', value: value, descriptionText: descriptionText, isStateChange: true, type: 'digital') // rbn.common#L872
    if (value == 'online') { // rbn.common#L873
        logInfo "${descriptionText}" // rbn.common#L874
    } // rbn.common#L875
    else { // rbn.common#L876
        if (settings?.txtEnable) { log.warn "${device.displayName} <b>${descriptionText}</b>" } // rbn.common#L877
    } // rbn.common#L878
} // rbn.common#L879

void updated() { // rbn.common#L882
    logInfo 'updated()...' // rbn.common#L883
    checkDriverVersion(state) // rbn.common#L884
    logInfo"driver version ${driverVersionAndTimeStamp()}" // rbn.common#L885
    unschedule() // rbn.common#L886

    if (settings.logEnable) { // rbn.common#L888
        logTrace(settings.toString()) // rbn.common#L889
        runIn(86400, 'logsOff') // rbn.common#L890
    } // rbn.common#L891
    if (settings.traceEnable) { // rbn.common#L892
        logTrace(settings.toString()) // rbn.common#L893
        runIn(1800, 'traceOff') // rbn.common#L894
    } // rbn.common#L895

    final int healthMethod = (settings.healthCheckMethod as Integer) ?: 0 // rbn.common#L897
    if (healthMethod == 1 || healthMethod == 2) { // rbn.common#L898

        final int interval = (settings.healthCheckInterval as Integer) ?: 0 // rbn.common#L900
        if (interval > 0) { // rbn.common#L901

            log.info "scheduling health check every ${interval} minutes by ${HealthcheckMethodOpts.options[healthMethod]} method" // rbn.common#L903
            scheduleDeviceHealthCheck(interval, healthMethod) // rbn.common#L904
        } // rbn.common#L905
    } // rbn.common#L906
    else { // rbn.common#L907
        unScheduleDeviceHealthCheck() // rbn.common#L908
        log.info 'Health Check is disabled!' // rbn.common#L909
    } // rbn.common#L910
    if (this.respondsTo('customUpdated')) { // rbn.common#L911
        customUpdated() // rbn.common#L912
    } // rbn.common#L913

    sendInfoEvent('updated') // rbn.common#L915
} // rbn.common#L916

private void logsOff() { // rbn.common#L918
    logInfo 'debug logging disabled...' // rbn.common#L919
    device.updateSetting('logEnable', [value: 'false', type: 'bool']) // rbn.common#L920
} // rbn.common#L921
private void traceOff() { // rbn.common#L922
    logInfo 'trace logging disabled...' // rbn.common#L923
    device.updateSetting('traceEnable', [value: 'false', type: 'bool']) // rbn.common#L924
} // rbn.common#L925

public void deviceUtilities(String command = null) { // rbn.common#L928
    logInfo "deviceUtilities(${command})..." // rbn.common#L929
    if (command == null || !(command in (ConfigureOpts.keySet() as List))) { // rbn.common#L930
        configureHelp(command) // rbn.common#L931
        return // rbn.common#L932
    } // rbn.common#L933

    String func // rbn.common#L935
    try { // rbn.common#L936
        func = ConfigureOpts[command]?.function // rbn.common#L937
        "$func"() // rbn.common#L938
    } // rbn.common#L939
    catch (e) { // rbn.common#L940
        logWarn "Exception ${e} caught while processing <b>$func</b>(<b>$value</b>)" // rbn.common#L941
        return // rbn.common#L942
    } // rbn.common#L943
    logInfo "executed '${func}'" // rbn.common#L944
} // rbn.common#L945

void configureHelp(final String val = null) { // rbn.common#L948
    logInfo "select one of the commands from the list: ${ConfigureOpts.keySet() as List}" // rbn.common#L949
    sendInfoEvent('Please select a command from the drop-down list') // rbn.common#L950
} // rbn.common#L951

public void loadAllDefaults() { // rbn.common#L953
    logDebug 'loadAllDefaults() !!!' // rbn.common#L954
    deleteAllSettings() // rbn.common#L955
    deleteAllCurrentStates() // rbn.common#L956
    deleteAllScheduledJobs() // rbn.common#L957
    deleteAllStates() // rbn.common#L958
    deleteAllChildDevices() // rbn.common#L959

    initialize() // rbn.common#L961
    configureNow() // rbn.common#L962
    updated() // rbn.common#L963
    sendInfoEvent('All Defaults Loaded! F5 to refresh') // rbn.common#L964
} // rbn.common#L965

private void configureNow() { // rbn.common#L967
    configure() // rbn.common#L968
} // rbn.common#L969

void configure() { // rbn.common#L976
    List<String> cmds = [] // rbn.common#L977
    if (state.stats == null) { state.stats = [:] } ; state.stats.cfgCtr = (state.stats.cfgCtr ?: 0) + 1 // rbn.common#L978
    logInfo "configure()... cfgCtr=${state.stats.cfgCtr}" // rbn.common#L979
    logDebug "configure(): settings: $settings" // rbn.common#L980
    aqaraBlackMagic() // rbn.common#L981
    List<String> initCmds = initializeDevice() // rbn.common#L982
    if (initCmds != null && !initCmds.isEmpty()) { cmds += initCmds } // rbn.common#L983
    List<String> cfgCmds = configureDevice() // rbn.common#L984
    if (cfgCmds != null && !cfgCmds.isEmpty()) { cmds += cfgCmds } // rbn.common#L985
    if (cmds != null && !cmds.isEmpty()) { // rbn.common#L986
        sendZigbeeCommands(cmds) // rbn.common#L987
        logDebug "configure(): sent cmds = ${cmds}" // rbn.common#L988
        sendInfoEvent('sent device configuration') // rbn.common#L989
    } // rbn.common#L990
    else { // rbn.common#L991
        logDebug "configure(): no commands defined for device type ${DEVICE_TYPE}" // rbn.common#L992
    } // rbn.common#L993
} // rbn.common#L994

void installed() { // rbn.common#L997
    if (state.stats == null) { state.stats = [:] } ; state.stats.instCtr = (state.stats.instCtr ?: 0) + 1 // rbn.common#L998
    logInfo "installed()... instCtr=${state.stats.instCtr}" // rbn.common#L999

    sendEvent(name: 'healthStatus', value: 'unknown', descriptionText: 'device was installed', type: 'digital') // rbn.common#L1001
    sendEvent(name: 'powerSource',  value: 'unknown', descriptionText: 'device was installed', type: 'digital') // rbn.common#L1002
    sendInfoEvent('installed') // rbn.common#L1003
    runIn(3, 'updated') // rbn.common#L1004
    runIn(5, 'queryPowerSource') // rbn.common#L1005
} // rbn.common#L1006

private void queryPowerSource() { // rbn.common#L1008
    sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, 0x0007, [:], 0)) // rbn.common#L1009
} // rbn.common#L1010

private void initialize() { // rbn.common#L1013
    if (state.stats == null) { state.stats = [:] } ; state.stats.initCtr = (state.stats.initCtr ?: 0) + 1 // rbn.common#L1014
    logDebug "initialize()... initCtr=${state.stats.initCtr}" // rbn.common#L1015
    if (device.getDataValue('powerSource') == null) { // rbn.common#L1016
        logDebug "initializing device powerSource 'unknown'" // rbn.common#L1017
        sendEvent(name: 'powerSource', value: 'unknown', type: 'digital') // rbn.common#L1018
    } // rbn.common#L1019
    if (this.respondsTo('customInitialize')) { customInitialize() } // rbn.common#L1020
    initializeVars(fullInit = true) // rbn.common#L1021
    updateAqaraVersion() // rbn.common#L1022
} // rbn.common#L1023

static Integer safeToInt(Object val, Integer defaultVal=0) { // rbn.common#L1031
    return "${val}"?.isInteger() ? "${val}".toInteger() : defaultVal // rbn.common#L1032
} // rbn.common#L1033

static Double safeToDouble(Object val, Double defaultVal=0.0) { // rbn.common#L1035
    return "${val}"?.isDouble() ? "${val}".toDouble() : defaultVal // rbn.common#L1036
} // rbn.common#L1037

static BigDecimal safeToBigDecimal(Object val, BigDecimal defaultVal=0.0) { // rbn.common#L1039
    return "${val}"?.isBigDecimal() ? "${val}".toBigDecimal() : defaultVal // rbn.common#L1040
} // rbn.common#L1041

public void sendZigbeeCommands(List<String> cmd) { // rbn.common#L1043
    if (cmd == null || cmd.isEmpty()) { // rbn.common#L1044
        logWarn "sendZigbeeCommands: list is empty! cmd=${cmd}" // rbn.common#L1045
        return // rbn.common#L1046
    } // rbn.common#L1047
    hubitat.device.HubMultiAction allActions = new hubitat.device.HubMultiAction() // rbn.common#L1048
    cmd.each { // rbn.common#L1049
        if (it == null || it.isEmpty() || it == 'null') { // rbn.common#L1050
            logWarn "sendZigbeeCommands it: no commands to send! it=${it} (cmd=${cmd})" // rbn.common#L1051
            return // rbn.common#L1052
        } // rbn.common#L1053
        allActions.add(new hubitat.device.HubAction(it, hubitat.device.Protocol.ZIGBEE)) // rbn.common#L1054
        if (state.stats != null) { state.stats['txCtr'] = (state.stats['txCtr'] ?: 0) + 1 } else { state.stats = [:] } // rbn.common#L1055
    } // rbn.common#L1056
    if (state.lastTx != null) { state.lastTx['cmdTime'] = now() } else { state.lastTx = [:] } // rbn.common#L1057
    sendHubCommand(allActions) // rbn.common#L1058
    logDebug "sendZigbeeCommands: sent cmd=${cmd}" // rbn.common#L1059
} // rbn.common#L1060

private String driverVersionAndTimeStamp() { version() + ' ' + timeStamp() + ((_DEBUG) ? ' (debug version!) ' : ' ') + "(${device.getDataValue('model')} ${device.getDataValue('manufacturer')}) (${getModel()} ${location.hub.firmwareVersionString})" } // rbn.common#L1062

private String getDeviceInfo() { // rbn.common#L1064
    return "model=${device.getDataValue('model')} manufacturer=${device.getDataValue('manufacturer')} destinationEP=${state.destinationEP ?: UNKNOWN} <b>deviceProfile=${state.deviceProfile ?: UNKNOWN}</b>" // rbn.common#L1065
} // rbn.common#L1066

public String getDestinationEP() { // rbn.common#L1068
    return state.destinationEP ?: device.endpointId ?: '01' // rbn.common#L1069
} // rbn.common#L1070

public void checkDriverVersion(final Map stateCopy) { // rbn.common#L1073
    if (stateCopy.driverVersion == null || driverVersionAndTimeStamp() != stateCopy.driverVersion) { // rbn.common#L1074
        logDebug "checkDriverVersion: updating the settings from the current driver version ${stateCopy.driverVersion} to the new version ${driverVersionAndTimeStamp()}" // rbn.common#L1075
        sendInfoEvent("Updated to version ${driverVersionAndTimeStamp()} from version ${stateCopy.driverVersion ?: 'unknown'}") // rbn.common#L1076
        state.driverVersion = driverVersionAndTimeStamp() // rbn.common#L1077
        initializeVars(false) // rbn.common#L1078
        updateAqaraVersion() // rbn.common#L1079
        if (this.respondsTo('customcheckDriverVersion')) { customcheckDriverVersion(stateCopy) } // rbn.common#L1080
    } // rbn.common#L1081
    if (state.states == null) { state.states = [:] } ; if (state.lastRx == null) { state.lastRx = [:] } ; if (state.lastTx == null) { state.lastTx = [:] } ; if (state.stats  == null) { state.stats =  [:] } // rbn.common#L1082
} // rbn.common#L1083

String getModel() { // rbn.common#L1086
    try { // rbn.common#L1087

        String model = getHubVersion() // rbn.common#L1089
    } catch (ignore) { // rbn.common#L1090
        try { // rbn.common#L1091
            httpGet("http://${location.hub.localIP}:8080/api/hubitat.xml") { res -> // rbn.common#L1092
                model = res.data.device.modelName // rbn.common#L1093
                return model // rbn.common#L1094
            } // rbn.common#L1095
        } catch (ignore_again) { // rbn.common#L1096
            return '' // rbn.common#L1097
        } // rbn.common#L1098
    } // rbn.common#L1099
} // rbn.common#L1100

boolean isCompatible(Integer minLevel) { // rbn.common#L1103
    String model = getModel() // rbn.common#L1104
    String[] tokens = model.split('-') // rbn.common#L1105
    String revision = tokens.last() // rbn.common#L1106
    return (Integer.parseInt(revision) >= minLevel) // rbn.common#L1107
} // rbn.common#L1108

void deleteAllStatesAndJobs() { // rbn.common#L1110
    state.clear() // rbn.common#L1111
    unschedule() // rbn.common#L1112
    device.deleteCurrentState('*') // rbn.common#L1113
    device.deleteCurrentState('') // rbn.common#L1114

    log.info "${device.displayName} jobs and states cleared. HE hub is ${getHubVersion()}, version is ${location.hub.firmwareVersionString}" // rbn.common#L1116
} // rbn.common#L1117

void resetStatistics() { // rbn.common#L1119
    runIn(1, 'resetStats') // rbn.common#L1120
    sendInfoEvent('Statistics are reset. Refresh the web page') // rbn.common#L1121
} // rbn.common#L1122

void resetStats() { // rbn.common#L1125
    logDebug 'resetStats...' // rbn.common#L1126
    state.stats = [:] ; state.states = [:] ; state.lastRx = [:] ; state.lastTx = [:] ; state.health = [:] // rbn.common#L1127
    if (this.respondsTo('groupsLibVersion')) { state.zigbeeGroups = [:] } // rbn.common#L1128
    state.stats.rxCtr = 0 ; state.stats.txCtr = 0 // rbn.common#L1129
    state.states['isDigital'] = false ; state.states['isRefresh'] = false ; state.states['isPing'] = false // rbn.common#L1130
    state.health['offlineCtr'] = 0 ; state.health['checkCtr3'] = 0 // rbn.common#L1131
    if (this.respondsTo('customResetStats')) { customResetStats() } // rbn.common#L1132
    logInfo 'statistics reset!' // rbn.common#L1133
} // rbn.common#L1134

void initializeVars( boolean fullInit = false ) { // rbn.common#L1136
    logDebug "InitializeVars()... fullInit = ${fullInit}" // rbn.common#L1137
    if (fullInit == true ) { // rbn.common#L1138
        state.clear() // rbn.common#L1139
        unschedule() // rbn.common#L1140
        resetStats() // rbn.common#L1141
        if (this.respondsTo('setDeviceNameAndProfile')) { setDeviceNameAndProfile() } // rbn.common#L1142

        logInfo 'all states and scheduled jobs cleared!' // rbn.common#L1144
        state.driverVersion = driverVersionAndTimeStamp() // rbn.common#L1145
        logInfo "DEVICE_TYPE = ${DEVICE_TYPE}" // rbn.common#L1146
        state.deviceType = DEVICE_TYPE // rbn.common#L1147
        sendInfoEvent('Initialized') // rbn.common#L1148
    } // rbn.common#L1149

    if (state.stats == null)  { state.stats  = [:] } // rbn.common#L1151
    if (state.states == null) { state.states = [:] } // rbn.common#L1152
    if (state.lastRx == null) { state.lastRx = [:] } // rbn.common#L1153
    if (state.lastTx == null) { state.lastTx = [:] } // rbn.common#L1154
    if (state.health == null) { state.health = [:] } // rbn.common#L1155

    if (fullInit || settings?.txtEnable == null) { device.updateSetting('txtEnable', true) } // rbn.common#L1157
    if (fullInit || settings?.logEnable == null) { device.updateSetting('logEnable', DEFAULT_DEBUG_LOGGING ?: false) } // rbn.common#L1158
    if (fullInit || settings?.traceEnable == null) { device.updateSetting('traceEnable', false) } // rbn.common#L1159
    if (fullInit || settings?.advancedOptions == null) { device.updateSetting('advancedOptions', [value:false, type:'bool']) } // rbn.common#L1160
    if (fullInit || settings?.healthCheckMethod == null) { device.updateSetting('healthCheckMethod', [value: HealthcheckMethodOpts.defaultValue.toString(), type: 'enum']) } // rbn.common#L1161
    if (fullInit || settings?.healthCheckInterval == null) { device.updateSetting('healthCheckInterval', [value: HealthcheckIntervalOpts.defaultValue.toString(), type: 'enum']) } // rbn.common#L1162
    if (fullInit || settings?.ignoreDuplicatedZigbeeMessages == null) { device.updateSetting('ignoreDuplicatedZigbeeMessages', false) } // rbn.common#L1163
    if (fullInit || settings?.voltageToPercent == null) { device.updateSetting('voltageToPercent', false) } // rbn.common#L1164

    if (device.currentValue('healthStatus') == null) { sendHealthStatusEvent('unknown') } // rbn.common#L1166

    executeCustomHandler('batteryInitializeVars', fullInit) // rbn.common#L1169
    executeCustomHandler('motionInitializeVars', fullInit) // rbn.common#L1170
    executeCustomHandler('groupsInitializeVars', fullInit) // rbn.common#L1171
    executeCustomHandler('illuminanceInitializeVars', fullInit) // rbn.common#L1172
    executeCustomHandler('onOfInitializeVars', fullInit) // rbn.common#L1173
    executeCustomHandler('energyInitializeVars', fullInit) // rbn.common#L1174

    executeCustomHandler('deviceProfileInitializeVars', fullInit) // rbn.common#L1176
    executeCustomHandler('initEventsDeviceProfile', fullInit) // rbn.common#L1177

    executeCustomHandler('customInitializeVars', fullInit) // rbn.common#L1180
    executeCustomHandler('customCreateChildDevices', fullInit) // rbn.common#L1181
    executeCustomHandler('customInitEvents', fullInit) // rbn.common#L1182

    final String mm = device.getDataValue('model') // rbn.common#L1184
    if (mm != null) { logTrace " model = ${mm}" } // rbn.common#L1185
    else { logWarn ' Model not found, please re-pair the device!' } // rbn.common#L1186
    final String ep = device.getEndpointId() // rbn.common#L1187
    if ( ep  != null) { // rbn.common#L1188

        logTrace " destinationEP = ${ep}" // rbn.common#L1190
    } // rbn.common#L1191
    else { // rbn.common#L1192
        logWarn ' Destination End Point not found, please re-pair the device!' // rbn.common#L1193

    } // rbn.common#L1195
} // rbn.common#L1196

void setDestinationEP() { // rbn.common#L1199
    String ep = device.getEndpointId() // rbn.common#L1200
    if (ep != null && ep != 'F2') { state.destinationEP = ep ; logDebug "setDestinationEP() destinationEP = ${state.destinationEP}" } // rbn.common#L1201
    else { logWarn "setDestinationEP() Destination End Point not found or invalid(${ep}), activating the F2 bug patch!" ; state.destinationEP = '01' } // rbn.common#L1202
} // rbn.common#L1203

void logDebug(final String msg) { if (settings?.logEnable)   { log.debug "${device.displayName} " + msg } } // rbn.common#L1205
void logInfo(final String msg)  { if (settings?.txtEnable)   { log.info  "${device.displayName} " + msg } } // rbn.common#L1206
void logWarn(final String msg)  { if (settings?.logEnable)   { log.warn  "${device.displayName} " + msg } } // rbn.common#L1207
void logTrace(final String msg) { if (settings?.traceEnable) { log.trace "${device.displayName} " + msg } } // rbn.common#L1208
void logError(final String msg) { if (settings?.txtEnable)   { log.error "${device.displayName} " + msg } } // rbn.common#L1209

void getAllProperties() { // rbn.common#L1212
    log.trace 'Properties:' ; device.properties.each { it -> log.debug it } // rbn.common#L1213
    log.trace 'Settings:' ;  settings.each { it -> log.debug "${it.key} =  ${it.value}" } // rbn.common#L1214
} // rbn.common#L1215

void deleteAllSettings() { // rbn.common#L1218
    String preferencesDeleted = '' // rbn.common#L1219
    settings.each { it -> preferencesDeleted += "${it.key} (${it.value}), " ; device.removeSetting("${it.key}") } // rbn.common#L1220
    logDebug "Deleted settings: ${preferencesDeleted}" // rbn.common#L1221
    logInfo  'All settings (preferences) DELETED' // rbn.common#L1222
} // rbn.common#L1223

void deleteAllCurrentStates() { // rbn.common#L1226
    String attributesDeleted = '' // rbn.common#L1227
    device.properties.supportedAttributes.each { it -> attributesDeleted += "${it}, " ; device.deleteCurrentState("$it") } // rbn.common#L1228
    logDebug "Deleted attributes: ${attributesDeleted}" ; logInfo 'All current states (attributes) DELETED' // rbn.common#L1229
} // rbn.common#L1230

void deleteAllStates() { // rbn.common#L1233
    String stateDeleted = '' // rbn.common#L1234
    state.each { it -> stateDeleted += "${it.key}, " } // rbn.common#L1235
    state.clear() // rbn.common#L1236
    logDebug "Deleted states: ${stateDeleted}" ; logInfo 'All States DELETED' // rbn.common#L1237
} // rbn.common#L1238

void deleteAllScheduledJobs() { // rbn.common#L1240
    unschedule() ; logInfo 'All scheduled jobs DELETED' // rbn.common#L1241
} // rbn.common#L1242

void deleteAllChildDevices() { // rbn.common#L1244
    getChildDevices().each { child -> log.info "${device.displayName} Deleting ${child.deviceNetworkId}" ; deleteChildDevice(child.deviceNetworkId) } // rbn.common#L1245
    sendInfoEvent 'All child devices DELETED' // rbn.common#L1246
} // rbn.common#L1247

void testParse(String par) { // rbn.common#L1249

    log.trace '------------------------------------------------------' // rbn.common#L1251
    log.warn "testParse - <b>START</b> (${par})" // rbn.common#L1252
    parse(par) // rbn.common#L1253
    log.warn "testParse -   <b>END</b> (${par})" // rbn.common#L1254
    log.trace '------------------------------------------------------' // rbn.common#L1255
} // rbn.common#L1256

Object testJob() { // rbn.common#L1258
    log.warn 'test job executed' // rbn.common#L1259
} // rbn.common#L1260

String getCron(int timeInSeconds) { // rbn.common#L1266

    final Random rnd = new Random() // rbn.common#L1269
    int minutes = (timeInSeconds / 60 ) as int // rbn.common#L1270
    int  hours = (minutes / 60 ) as int // rbn.common#L1271
    if (hours > 23) { hours = 23 } // rbn.common#L1272
    String cron // rbn.common#L1273
    if (timeInSeconds < 60) { cron = "*/$timeInSeconds * * * * ? *" } // rbn.common#L1274
    else { // rbn.common#L1275
        if (minutes < 60) {   cron = "${rnd.nextInt(59)} ${rnd.nextInt(9)}/$minutes * ? * *" } // rbn.common#L1276
        else {                cron = "${rnd.nextInt(59)} ${rnd.nextInt(59)} */$hours ? * *"  } // rbn.common#L1277
    } // rbn.common#L1278
    return cron // rbn.common#L1279
} // rbn.common#L1280

String formatUptime() { // rbn.common#L1283
    return formatTime(location.hub.uptime) // rbn.common#L1284
} // rbn.common#L1285

String formatTime(int timeInSeconds) { // rbn.common#L1287
    if (timeInSeconds == null) { return UNKNOWN } // rbn.common#L1288
    int days = (timeInSeconds / 86400).toInteger() // rbn.common#L1289
    int hours = ((timeInSeconds % 86400) / 3600).toInteger() // rbn.common#L1290
    int minutes = ((timeInSeconds % 3600) / 60).toInteger() // rbn.common#L1291
    int seconds = (timeInSeconds % 60).toInteger() // rbn.common#L1292
    return "${days}d ${hours}h ${minutes}m ${seconds}s" // rbn.common#L1293
} // rbn.common#L1294

boolean isAqara() { return device.getDataValue('model')?.startsWith('lumi') ?: false } // rbn.common#L1296

void updateAqaraVersion() { // rbn.common#L1298
    if (!isAqara()) { logTrace 'not Aqara' ; return } // rbn.common#L1299
    String application = device.getDataValue('application') // rbn.common#L1300
    if (application != null) { // rbn.common#L1301
        String str = '0.0.0_' + String.format('%04d', zigbee.convertHexToInt(application.take(2))) // rbn.common#L1302
        if (device.getDataValue('aqaraVersion') != str) { // rbn.common#L1303
            device.updateDataValue('aqaraVersion', str) // rbn.common#L1304
            logInfo "aqaraVersion set to $str" // rbn.common#L1305
        } // rbn.common#L1306
    } // rbn.common#L1307
} // rbn.common#L1308

String unix2formattedDate(Long unixTime) { // rbn.common#L1310
    try { // rbn.common#L1311
        if (unixTime == null) { return null } // rbn.common#L1312

        Date date = new Date(unixTime.toLong()) // rbn.common#L1314
        return date.format('yyyy-MM-dd HH:mm:ss.SSS', location.timeZone) // rbn.common#L1315
    } catch (e) { // rbn.common#L1316
        logDebug "Error formatting date: ${e.message}. Returning current time instead." // rbn.common#L1317
        return new Date().format('yyyy-MM-dd HH:mm:ss.SSS', location.timeZone) // rbn.common#L1318
    } // rbn.common#L1319
} // rbn.common#L1320

Long formattedDate2unix(String formattedDate) { // rbn.common#L1322
    try { // rbn.common#L1323
        if (formattedDate == null) { return null } // rbn.common#L1324
        Date date = Date.parse('yyyy-MM-dd HH:mm:ss.SSS', formattedDate) // rbn.common#L1325
        return date.getTime() // rbn.common#L1326
    } catch (e) { // rbn.common#L1327
        logDebug "Error parsing formatted date: ${formattedDate}. Returning current time instead." // rbn.common#L1328
        return now() // rbn.common#L1329
    } // rbn.common#L1330
} // rbn.common#L1331

static String timeToHMS(final int time) { // rbn.common#L1333
    int hours = (time / 3600) as int // rbn.common#L1334
    int minutes = ((time % 3600) / 60) as int // rbn.common#L1335
    int seconds = time % 60 // rbn.common#L1336
    return "${hours}h ${minutes}m ${seconds}s" // rbn.common#L1337
} // rbn.common#L1338
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
