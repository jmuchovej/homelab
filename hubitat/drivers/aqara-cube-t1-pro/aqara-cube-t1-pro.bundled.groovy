/* groovylint-disable CompileStatic, DuplicateListLiteral, DuplicateMapLiteral, DuplicateNumberLiteral, DuplicateStringLiteral, ImplicitClosureParameter, ImplicitReturnStatement, InsecureRandom, LineLength, MethodCount, MethodReturnTypeRequired, MethodSize, NglParseError, NoDef, ParameterName, PublicMethodsBeforeNonPublicMethods, StaticMethodsBeforeInstanceMethods, UnnecessaryGetter, UnnecessaryGroovyImport, UnnecessaryObjectReferences, UnnecessaryPackageReference, UnusedImport, UnusedPrivateMethod, VariableName */
/**
 *  Aqara Cube T1 Pro - Device Driver for Hubitat Elevation
 *
 *  https://community.hubitat.com/t/alpha-aqara-cube-t1-pro-mfczq12lm-c-7/121604
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
 * This driver is inspired by @w35l3y work on Tuya device driver (Edge project).
 * For a big portions of code all credits go to Jonathan Bradshaw.
 *
 * Forked from https://github.com/kkossev/Hubitat (Drivers/Aqara Cube T1 Pro/Aqara_Cube_T1_Pro.groovy) at commit 0bf47407.
 * Modified for the rbn namespace: includes, namespace, and importUrl point at the rbn libraries; identity.
 *
 * ver. 2.1.0  2023-07-15 kkossev  - Libraries first introduction for the Aqara Cube T1 Pro driver; Fingerbot driver; Aqara devices: store NWK in states; aqaraVersion bug fix;
 * ver. 2.1.1  2023-07-16 kkossev  - Aqara Cube T1 Pro fixes and improvements; implemented configure() and loadAllDefaults commands;
 * ver. 3.0.6  2024-04-06 kkossev  - (dev. branch) commonLib 3.0.6
 * ver. 3.2.0  2024-05-21 kkossev  - (dev. branch) commonLib 3.2.0
 * ver. 3.3.0  2026-08-27 kkossev  - (dev. branch) commonLib 4.1.1
 * ver. 3.3.0  2026-09-30 rbn      - ported to the rbn libraries (rbn.common 4.1.1 with the Tuya path removed); no functional change
 */

static String version() { "3.3.0" }
static String timeStamp() {"2026/09/30 06:00 PM"}

@Field static final Boolean _DEBUG = false

import groovy.transform.Field
import hubitat.device.HubMultiAction
import hubitat.device.Protocol
import hubitat.helper.HexUtils
import hubitat.zigbee.zcl.DataType
import java.util.concurrent.ConcurrentHashMap
import groovy.json.JsonOutput

deviceType = "AqaraCube"
@Field static final String DEVICE_TYPE = "AqaraCube"

// #include rbn.common  -- included at line 384
// #include rbn.switch  -- included at line 1625
// #include rbn.xiaomi  -- included at line 1868
// #include rbn.button  -- included at line 2193
// #include rbn.battery  -- included at line 2278

metadata {
    definition (
        name: 'Aqara Cube T1 Pro',
        importUrl: 'https://raw.githubusercontent.com/jmuchovej/homelab/main/hubitat/drivers/aqara-cube-t1-pro/aqara-cube-t1-pro.bundled.groovy',
        namespace: 'rbn', author: 'Krassimir Kossev', singleThreaded: true )
    {
        // deviceType specific capabilities, commands and attributes
        capability "Sensor"
        capability "PushableButton"
        capability "DoubleTapableButton"
        capability "HoldableButton"
        capability "ReleasableButton"
        capability 'Battery'

        attribute 'batteryVoltage', 'number'
        attribute "operationMode", "enum", AqaraCubeModeOpts.options.values() as List<String>
        attribute "action", "enum", (AqaraCubeSceneModeOpts.options.values() + AqaraCubeActionModeOpts.options.values()) as List<String>
        attribute "cubeSide", "enum", AqaraCubeSideOpts.options.values() as List<String>
        attribute "angle", "number"
        attribute "sideUp", "number"

        command "push", [[name: "sent when the cube side is flipped", type: "NUMBER", description: "simulates a button press", defaultValue : ""]]
        command "doubleTap", [[name: "sent when the cube side is shaken", type: "NUMBER", description: "simulates a button press", defaultValue : ""]]
        command "release", [[name: "sent when the cube is rotated right", type: "NUMBER", description: "simulates a button press", defaultValue : ""]]
        command "hold", [[name: "sent when the cube is rotated left", type: "NUMBER", description: "simulates a button press", defaultValue : ""]]
    }

    fingerprint profileId:"0104", endpointId:"01", inClusters:"0000,0003,0001,0012,0006", outClusters:"0000,0003,0019", model:"lumi.remote.cagl02", manufacturer:"LUMI", deviceJoinName: "Aqara Cube T1 Pro"
    fingerprint profileId:"0104", endpointId:"01", inClusters:"0000,0003,0006", outClusters:"0000,0003", model:"lumi.remote.cagl02", manufacturer:"LUMI", deviceJoinName: "Aqara Cube T1 Pro"                        // https://community.hubitat.com/t/alpha-aqara-cube-t1-pro-c-7/121604/11?u=kkossev

    preferences {
        input name: 'txtEnable', type: 'bool', title: '<b>Enable descriptionText logging</b>', defaultValue: true, description: '<i>Enables command logging.</i>'
        input name: 'logEnable', type: 'bool', title: '<b>Enable debug logging</b>', defaultValue: true, description: '<i>Turns on debug logging for 24 hours.</i>'
        input name: 'cubeOperationMode', type: 'enum', title: '<b>Cube Operation Mode</b>', options: AqaraCubeModeOpts.options, defaultValue: AqaraCubeModeOpts.defaultValue, required: true, description: '<i>Operation Mode.<br>Press LINK button 5 times to toggle between action mode and scene mode</i>'
        input name: 'sendButtonEvent', type: 'enum', title: '<b>Send Button Event</b>', options: SendButtonEventOpts.options, defaultValue: SendButtonEventOpts.defaultValue, required: true, description: '<i>Send button events on cube actions</i>'
    }
}

// https://github.com/Koenkk/zigbee2mqtt/issues/15652
// https://homekitnews.com/2022/02/17/aqara-cube-t1-pro-review/

@Field static final Map AqaraCubeModeOpts = [
    defaultValue: 1,
    options     : [0: 'action', 1: 'scene']
]

/////////////////////// scene mode /////////////////////
@Field static final Map AqaraCubeSceneModeOpts = [
    defaultValue: 0,
    options     : [
        1: 'shake',           // activated when the cube is shaken
        2: 'hold',            // activated if user picks up the cube and holds it
        3: 'sideUp',          // activated when the cube is resting on a surface
        4: 'inactivity',      // (not used!)
        5: 'flipToSide',      // (not used!) activated when the cube is flipped on a surface
        6: 'rotateLeft',      // activated when the cube is rotated left on a surface
        7: 'rotateRight',     // activated when the cube is rotated right on a surface
        8: 'throw'            // activated after a throw motion
    ]
]

//------------------- action mode -----------------
@Field static final Map AqaraCubeActionModeOpts = [
    defaultValue: 0,
    options     : [
        0: 'slide',
        1: 'rotate',
        2: 'tapTwice',
        3: 'flip90',
        4: 'flip180',
        5: 'shake',
        6: 'inactivity'
    ]
]

@Field static final Map AqaraCubeSideOpts = [
    defaultValue: 0,
    options     : [
        0: 'actionFromSide',
        1: 'actionSide',
        2: 'actionToSide',
        3: 'side',                 // Destination side of action
        4: 'sideUp'                // Upfacing side of current scene
    ]
]

@Field static final Map SendButtonEventOpts = [
    defaultValue: 0,
    options     : [0: 'disabled', 1: 'enabled']
]

def customRefresh() {
    List<String> cmds = []
    cmds += zigbee.readAttribute(0x0001, 0x0020, [:], delay=200)                 // battery voltage
    cmds += zigbee.readAttribute(0xFCC0, 0x0009, [mfgCode: 0x115F], delay=200)
    cmds += zigbee.readAttribute(0xFCC0, 0x0148, [mfgCode: 0x115F], delay=200)   // operation_mode
    cmds += zigbee.readAttribute(0xFCC0, 0x0149, [mfgCode: 0x115F], delay=200)   // side_up attribute report
    logDebug "customRefresh() : ${cmds}"
    return cmds
}

def customInitializeVars(boolean fullInit=false) {
    logDebug "customInitializeVars(${fullInit})"
    if (fullInit || settings?.cubeOperationMode == null) device.updateSetting('cubeOperationMode', [value: AqaraCubeModeOpts.defaultValue.toString(), type: 'enum'])
    if (fullInit || settings?.sendButtonEvent == null) device.updateSetting('sendButtonEvent', [value: SendButtonEventOpts.defaultValue.toString(), type: 'enum'])
    if (fullInit || settings?.voltageToPercent == null) device.updateSetting("voltageToPercent", true)        // overwrite the default false setting
}

void customInitEvents(boolean fullInit=false) {
    sendNumberOfButtonsEvent(6)
    def supportedValues = ["pushed", "double", "held", "released", "tested"]
    sendSupportedButtonValuesEvent(supportedValues)
}

/*
    configure: async (device, coordinatorEndpoint, logger) => {
        const endpoint = device.getEndpoint(1);
        await endpoint.write('aqaraOpple', {'mode': 1}, {manufacturerCode: 0x115f});
        await reporting.bind(endpoint, coordinatorEndpoint, ['genBasic','genOnOff','genPowerCfg','genMultistateInput']);
        await endpoint.read('genPowerCfg', ['batteryVoltage']);
        await endpoint.read('aqaraOpple', [0x0148], {manufacturerCode: 0x115f});
        await endpoint.read('aqaraOpple', [0x0149], {manufacturerCode: 0x115f});
    },

*/

def customConfigureDevice() {
    List<String> cmds = []
    cmds += ["he raw 0x${device.deviceNetworkId} 0 0 0x8002 {40 00 00 00 00 40 8f 5f 11 52 52 00 41 2c 52 00 00} {0x0000}", "delay 50",]                                                 // Aqara - Hubitat C-7 voodoo

    // await endpoint.write('aqaraOpple', {'mode': 1}, {manufacturerCode: 0x115f});
    def mode = settings?.cubeOperationMode != null ? settings.cubeOperationMode : AqaraCubeModeOpts.defaultValue
    logDebug "cubeOperationMode will be set to ${(AqaraCubeModeOpts.options[mode as int])} (${mode})"
    cmds += zigbee.writeAttribute(0xFCC0, 0x0009, 0x20, mode as int, [mfgCode: 0x115F], delay=200)

    // https://github.com/Koenkk/zigbee-herdsman-converters/pull/5367
    cmds += ["he raw 0x${device.deviceNetworkId} 1 ${device.endpointId} 0xFCC0 {14 5F 11 01 02 FF 00 41 10 45 65 21 20 75 38 17 69 78 53 89 51 13 16 49 58}  {0x0104}", "delay 50",]      // Aqara Cube T1 Pro voodoo

    // TODO - check if explicit binding is needed at all?
    cmds += ["zdo bind 0x${device.deviceNetworkId} 0x01 0x01 0x0000 {${device.zigbeeId}} {}", "delay 251", ]
    cmds += ["zdo bind 0x${device.deviceNetworkId} 0x01 0x01 0x0006 {${device.zigbeeId}} {}", "delay 251", ]
    cmds += ["zdo bind 0x${device.deviceNetworkId} 0x01 0x01 0x0001 {${device.zigbeeId}} {}", "delay 251", ]

    cmds += zigbee.readAttribute(0xFCC0, 0x0009, [mfgCode: 0x115F], delay=200)
    cmds += zigbee.readAttribute(0x0001, 0x0020, [:], delay=200)
    cmds += zigbee.readAttribute(0xFCC0, 0x0148, [mfgCode: 0x115F], delay=200)
    cmds += zigbee.readAttribute(0xFCC0, 0x0149, [mfgCode: 0x115F], delay=200)

    logDebug "customConfigureDevice() : ${cmds}"
    return cmds
}

/*
 # Clusters (Scene Mode):
  ## Endpoint 2:

  | Cluster            | Data                      | Description                   |
  | ------------------ | ------------------------- | ----------------------------- |
  | genMultistateInput | {presentValue: 0}         | action: shake                 |
  | genMultistateInput | {presentValue: 4}         | action: hold                  |
  | genMultistateInput | {presentValue: 2}         | action: wakeup                |
  | genMultistateInput | {presentValue: 1024-1029} | action: fall with ith side up |
*/
void customParseMultistateInputCluster(final Map descMap) {
    if (descMap.value == null || descMap.value == 'FFFF') { return } // invalid or unknown value
    def value = hexStrToUnsignedInt(descMap.value)
    logDebug "customParseMultistateInputCluster: (0x012)  attribute 0x${descMap.attrId} descMap.value=${descMap.value} value=${value}"
    String action = null
    Integer side = 0
    switch (value as Integer) {
        case 0:
            action = 'shake'
            break
        case 1:
            action = 'throw'
            break
        case 2:
            action = 'wakeup'
            break
        case 4:
            action = 'hold'
            break
        case 1024..1029 :
            action = 'flipToSide'
            side = value - 1024 + 1
            break
        default :
            logWarn "customParseMultistateInputCluster: unknown value: xiaomi cluster 0xFCC0 attribute 0x${descMap.attrId} (value ${descMap.value})"
            return
    }
    if (action != null) {
        def eventMap = [:]
        eventMap.value = action
        eventMap.name = "action"
        eventMap.unit = ""
        eventMap.type = "physical"
        eventMap.isStateChange = true    // always send these events as a change!
        String sideStr = ""
        if (action == "flipToSide") {
            sideStr = side.toString()
            eventMap.data = [side: side]
            // first send a sideUp event, so that the side number is available in the automation rule
            sendAqaraCubeSideUpEvent((side-1) as int)
        }
        eventMap.descriptionText = "${eventMap.name} is ${eventMap.value} ${sideStr} ${eventMap.unit}"
        sendEvent(eventMap)
        logInfo "${eventMap.descriptionText}"
        if (action == "shake") {
            if (settings?.sendButtonEvent){
                side = (device.currentValue('sideUp', true) ?: 0) as Integer
                sendButtonEvent(side, "doubleTapped", isDigital=true)
            }
        }
    }
    else {
        logWarn "customParseMultistateInputCluster: unknown action: ${action} xiaomi cluster 0xFCC0 attribute 0x${descMap.attrId} (value ${descMap.value})"
    }
}

// called from xiaomiLib - refactor !
void parseXiaomiClusterAqaraCube(final Map descMap) {
    logDebug "parseXiaomiClusterAqaraCube: cluster 0xFCC0 attribute 0x${descMap.attrId} ${descMap}"
    switch (descMap.attrInt as Integer) {
        case 0x0148 :                    // Aqara Cube T1 Pro - Mode
            final Integer value = hexStrToUnsignedInt(descMap.value)
            log.info "cubeMode is '${AqaraCubeModeOpts.options[value]}' (0x${descMap.value})"
            device.updateSetting('cubeOperationMode', [value: value.toString(), type: 'enum'])
            break
        case 0x0149:                     // (329) Aqara Cube T1 Pro - i side facing up (0..5)
            processSideFacingUp(descMap)
            break
        default:
            logWarn "parseXiaomiClusterAqaraCube: unknown xiaomi cluster 0xFCC0 attribute 0x${descMap.attrId} (value ${descMap.value})"
            break
    }
}

/*
 # Clusters (Scene Mode):
  ## Endpoint 2:

  | Cluster            | Data                      | Description                   |
  | ------------------ | ------------------------- | ----------------------------- |
  | aqaraopple         | {329: 0-5}                | i side facing up              |
*/
void processSideFacingUp(final Map descMap) {
    logDebug "processSideFacingUp: ${descMap}"
    if (descMap.value == null || descMap.value == 'FFFF') { return } // invalid or unknown value
    Integer value = hexStrToUnsignedInt(descMap.value)
    sendAqaraCubeSideUpEvent(value)
}

def sendAqaraCubeSideUpEvent(final Integer value) {
    if ((device.currentValue('sideUp', true) as Integer) == (value+1)) {
        logDebug "no change in sideUp (${(value+1)}), skipping..."
        return
    }
    if (value>=0 && value<=5) {
        def eventMap = [:]
        eventMap.value = value + 1
        eventMap.name = "sideUp"
        eventMap.unit = ""
        eventMap.type = "physical"
        eventMap.isStateChange = true
        eventMap.descriptionText = "${eventMap.name} is ${eventMap.value} ${eventMap.unit}"
        sendEvent(eventMap)
        logInfo "${eventMap.descriptionText}"
        if (settings?.sendButtonEvent){
            sendButtonEvent((value + 1) as Integer, "pushed", isDigital=true)
        }
    }
    else {
        logWarn "invalid Aqara Cube side facing up value=${value}"
    }
}

// called from xiaomiLib - refactor !
def sendAqaraCubeOperationModeEvent(final Integer mode)
{
    logDebug "sendAqaraCubeModeEvent: ${mode}"
    if (mode in [0,1]) {
        def eventMap = [:]
        eventMap.value = AqaraCubeModeOpts.options.values()[mode as int]
        eventMap.name = "operationMode"
        eventMap.unit = ""
        eventMap.type = "physical"
        eventMap.descriptionText = "${eventMap.name} is ${eventMap.value} (${mode})"
        sendEvent(eventMap)
        logInfo "${eventMap.descriptionText}"
    }
    else {
        logWarn "invalid Aqara Cube mode ${mode}"
    }
}

// 0x000C - Analog Input Cluster
void customParseAnalogInputCluster(final Map descMap) {
    logDebug "customParseAnalogInputCluster: (0x000C) attribute 0x${descMap.attrId} (value ${descMap.value})"
    if (descMap.value == null || descMap.value == 'FFFF') { logWarn "invalid or unknown value"; return } // invalid or unknown value
    if (descMap.attrId == "0055") {
        def value = hexStrToUnsignedInt(descMap.value)
        Float floatValue = Float.intBitsToFloat(value.intValue())
        logDebug "value=${value} floatValue=${floatValue}"
        sendAqaraCubeRotateEvent(floatValue as Integer)
    }
    else {
        logDebug "skipped attribute 0x${descMap.attrId}"
        return
    }
}

void sendAqaraCubeRotateEvent(final Integer degrees) {
    String leftRight = degrees < 0 ? 'rotateLeft' : 'rotateRight'

    def eventMap = [:]
    eventMap.name = "action"
    eventMap.value = leftRight
    eventMap.unit = "degrees"
    eventMap.type = "physical"
    eventMap.isStateChange = true    // always send these events as a change!
    eventMap.data = [degrees: degrees]
    eventMap.descriptionText = "${eventMap.name} is ${eventMap.value} ${degrees} ${eventMap.unit}"
    sendEvent(eventMap)
    logInfo "${eventMap.descriptionText}"
    if (settings?.sendButtonEvent){
        def side = (device.currentValue('sideUp', true) ?: 0) as Integer
        sendButtonEvent(side, leftRight == "rotateLeft" ? "held" : "released", isDigital=true)
    }
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

// ~~~~~ start include rbn.xiaomi ~~~~~
library( // rbn.xiaomi#L2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Xiaomi Library', name: 'xiaomi', namespace: 'rbn', importUrl: '', documentationLink: '', // rbn.xiaomi#L3
    version: '3.3.0' // rbn.xiaomi#L4
) // rbn.xiaomi#L5
/*
 *  Xiaomi Library
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
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/xiaomiLib.groovy) at commit 0bf47407.
 *  Modified for the rbn namespace: identity changes only.
 *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/xiaomi.groovy#L21-L29
*/

static String xiaomiLibVersion()   { '3.3.0' } // rbn.xiaomi#L32
static String xiaomiLibStamp() { '2024/06/23 9:36 AM' } // rbn.xiaomi#L33

boolean isAqaraTVOC_Lib()  { (device?.getDataValue('model') ?: 'n/a') in ['lumi.airmonitor.acn01'] } // rbn.xiaomi#L35
boolean isAqaraTVOC_OLD()  { (device?.getDataValue('model') ?: 'n/a') in ['lumi.airmonitor.acn01'] } // rbn.xiaomi#L36
boolean isAqaraCube()  { (device?.getDataValue('model') ?: 'n/a') in ['lumi.remote.cagl02'] } // rbn.xiaomi#L37
boolean isAqaraFP1()   { (device?.getDataValue('model') ?: 'n/a') in ['lumi.motion.ac01'] } // rbn.xiaomi#L38
boolean isAqaraTRV_OLD()   { (device?.getDataValue('model') ?: 'n/a') in ['lumi.airrtc.agl001'] } // rbn.xiaomi#L39

@Field static final int XIAOMI_CLUSTER_ID = 0xFCC0 // rbn.xiaomi#L43

@Field static final int DIRECTION_MODE_ATTR_ID = 0x0144 // rbn.xiaomi#L46
@Field static final int MODEL_ATTR_ID = 0x05 // rbn.xiaomi#L47
@Field static final int PRESENCE_ACTIONS_ATTR_ID = 0x0143 // rbn.xiaomi#L48
@Field static final int PRESENCE_ATTR_ID = 0x0142 // rbn.xiaomi#L49
@Field static final int REGION_EVENT_ATTR_ID = 0x0151 // rbn.xiaomi#L50
@Field static final int RESET_PRESENCE_ATTR_ID = 0x0157 // rbn.xiaomi#L51
@Field static final int SENSITIVITY_LEVEL_ATTR_ID = 0x010C // rbn.xiaomi#L52
@Field static final int SET_EDGE_REGION_ATTR_ID = 0x0156 // rbn.xiaomi#L53
@Field static final int SET_EXIT_REGION_ATTR_ID = 0x0153 // rbn.xiaomi#L54
@Field static final int SET_INTERFERENCE_ATTR_ID = 0x0154 // rbn.xiaomi#L55
@Field static final int SET_REGION_ATTR_ID = 0x0150 // rbn.xiaomi#L56
@Field static final int TRIGGER_DISTANCE_ATTR_ID = 0x0146 // rbn.xiaomi#L57
@Field static final int XIAOMI_RAW_ATTR_ID = 0xFFF2 // rbn.xiaomi#L58
@Field static final int XIAOMI_SPECIAL_REPORT_ID = 0x00F7 // rbn.xiaomi#L59
@Field static final Map MFG_CODE = [ mfgCode: 0x115F ] // rbn.xiaomi#L60

@Field static final int DIRECTION_MODE_TAG_ID = 0x67 // rbn.xiaomi#L63
@Field static final int SENSITIVITY_LEVEL_TAG_ID = 0x66 // rbn.xiaomi#L64
@Field static final int SWBUILD_TAG_ID = 0x08 // rbn.xiaomi#L65
@Field static final int TRIGGER_DISTANCE_TAG_ID = 0x69 // rbn.xiaomi#L66
@Field static final int PRESENCE_ACTIONS_TAG_ID = 0x66 // rbn.xiaomi#L67
@Field static final int PRESENCE_TAG_ID = 0x65 // rbn.xiaomi#L68

void standardParseXiaomiFCC0Cluster(final Map descMap) { // rbn.xiaomi#L73
    if (settings.logEnable) { // rbn.xiaomi#L74
        logTrace "standardParseXiaomiFCC0Cluster: zigbee received xiaomi cluster attribute 0x${descMap.attrId} (value ${descMap.value})" // rbn.xiaomi#L75
    } // rbn.xiaomi#L76
    if (DEVICE_TYPE in  ['Thermostat']) { // rbn.xiaomi#L77
        parseXiaomiClusterThermostatLib(descMap) // rbn.xiaomi#L78
        return // rbn.xiaomi#L79
    } // rbn.xiaomi#L80
    if (DEVICE_TYPE in  ['Bulb']) { // rbn.xiaomi#L81
        parseXiaomiClusterRgbLib(descMap) // rbn.xiaomi#L82
        return // rbn.xiaomi#L83
    } // rbn.xiaomi#L84

    final String funcName = 'standardParseXiaomiFCC0Cluster' // rbn.xiaomi#L87
    switch (descMap.attrInt as Integer) { // rbn.xiaomi#L88
        case 0x0009: // rbn.xiaomi#L89
            if (DEVICE_TYPE in  ['AqaraCube']) { logDebug "standardParseXiaomiFCC0Cluster: AqaraCube 0xFCC0 attribute 0x009 value is ${hexStrToUnsignedInt(descMap.value)}" } // rbn.xiaomi#L90
            else { logDebug "${funcName}: unknown attribute ${descMap.attrInt} value raw = ${hexStrToUnsignedInt(descMap.value)}" } // rbn.xiaomi#L91
            break // rbn.xiaomi#L92
        case 0x00FC: // rbn.xiaomi#L93
            logWarn "${funcName}: unknown attribute - resetting?" // rbn.xiaomi#L94
            break // rbn.xiaomi#L95
        case PRESENCE_ATTR_ID: // rbn.xiaomi#L96
            final Integer value = hexStrToUnsignedInt(descMap.value) // rbn.xiaomi#L97
            parseXiaomiClusterPresence(value) // rbn.xiaomi#L98
            break // rbn.xiaomi#L99
        case PRESENCE_ACTIONS_ATTR_ID: // rbn.xiaomi#L100
            final Integer value = hexStrToUnsignedInt(descMap.value) // rbn.xiaomi#L101
            parseXiaomiClusterPresenceAction(value) // rbn.xiaomi#L102
            break // rbn.xiaomi#L103
        case REGION_EVENT_ATTR_ID: // rbn.xiaomi#L104

            final Integer regionId = HexUtils.hexStringToInt(descMap.value[0..1]) // rbn.xiaomi#L106
            final Integer value = HexUtils.hexStringToInt(descMap.value[2..3]) // rbn.xiaomi#L107
            if (settings.logEnable) { // rbn.xiaomi#L108
                log.debug "${funcName}: xiaomi: region ${regionId} action is ${value}" // rbn.xiaomi#L109
            } // rbn.xiaomi#L110
            if (device.currentValue("region${regionId}") != null) { // rbn.xiaomi#L111
                RegionUpdateBuffer.get(device.id).put(regionId, value) // rbn.xiaomi#L112
                runInMillis(REGION_UPDATE_DELAY_MS, 'updateRegions') // rbn.xiaomi#L113
            } // rbn.xiaomi#L114
            break // rbn.xiaomi#L115
        case SENSITIVITY_LEVEL_ATTR_ID: // rbn.xiaomi#L116
            final Integer value = hexStrToUnsignedInt(descMap.value) // rbn.xiaomi#L117
            log.info "sensitivity level is '${SensitivityLevelOpts.options[value]}' (0x${descMap.value})" // rbn.xiaomi#L118
            device.updateSetting('sensitivityLevel', [value: value.toString(), type: 'enum']) // rbn.xiaomi#L119
            break // rbn.xiaomi#L120
        case TRIGGER_DISTANCE_ATTR_ID: // rbn.xiaomi#L121
            final Integer value = hexStrToUnsignedInt(descMap.value) // rbn.xiaomi#L122
            log.info "approach distance is '${ApproachDistanceOpts.options[value]}' (0x${descMap.value})" // rbn.xiaomi#L123
            device.updateSetting('approachDistance', [value: value.toString(), type: 'enum']) // rbn.xiaomi#L124
            break // rbn.xiaomi#L125
        case DIRECTION_MODE_ATTR_ID: // rbn.xiaomi#L126
            final Integer value = hexStrToUnsignedInt(descMap.value) // rbn.xiaomi#L127
            log.info "monitoring direction mode is '${DirectionModeOpts.options[value]}' (0x${descMap.value})" // rbn.xiaomi#L128
            device.updateSetting('directionMode', [value: value.toString(), type: 'enum']) // rbn.xiaomi#L129
            break // rbn.xiaomi#L130
        case 0x0148 : // rbn.xiaomi#L131
            if (DEVICE_TYPE in  ['AqaraCube']) { parseXiaomiClusterAqaraCube(descMap) } // rbn.xiaomi#L132
            else { logDebug "${funcName}: unknown attribute ${descMap.attrInt} value raw = ${hexStrToUnsignedInt(descMap.value)}" } // rbn.xiaomi#L133
            break // rbn.xiaomi#L134
        case 0x0149: // rbn.xiaomi#L135
            if (DEVICE_TYPE in  ['AqaraCube']) { parseXiaomiClusterAqaraCube(descMap) } // rbn.xiaomi#L136
            else { logDebug "${funcName}: unknown attribute ${descMap.attrInt} value raw = ${hexStrToUnsignedInt(descMap.value)}" } // rbn.xiaomi#L137
            break // rbn.xiaomi#L138
        case XIAOMI_SPECIAL_REPORT_ID: // rbn.xiaomi#L139
            final Map<Integer, Integer> tags = decodeXiaomiTags(descMap.value) // rbn.xiaomi#L140
            parseXiaomiClusterTags(tags) // rbn.xiaomi#L141
            if (isAqaraCube()) { // rbn.xiaomi#L142
                sendZigbeeCommands(customRefresh()) // rbn.xiaomi#L143
            } // rbn.xiaomi#L144
            break // rbn.xiaomi#L145
        case XIAOMI_RAW_ATTR_ID: // rbn.xiaomi#L146
            final byte[] rawData = HexUtils.hexStringToByteArray(descMap.value) // rbn.xiaomi#L147
            if (rawData.size() == 24 && settings.enableDistanceDirection) { // rbn.xiaomi#L148
                final int degrees = rawData[19] // rbn.xiaomi#L149
                final int distanceCm = (rawData[17] << 8) | (rawData[18] & 0x00ff) // rbn.xiaomi#L150
                if (settings.logEnable) { // rbn.xiaomi#L151
                    log.debug "location ${degrees}&deg;, ${distanceCm}cm" // rbn.xiaomi#L152
                } // rbn.xiaomi#L153
                runIn(1, 'updateLocation', [ data: [ degrees: degrees, distanceCm: distanceCm ] ]) // rbn.xiaomi#L154
            } // rbn.xiaomi#L155
            break // rbn.xiaomi#L156
        default: // rbn.xiaomi#L157
            log.warn "${funcName}: zigbee received unknown xiaomi cluster 0xFCC0 attribute 0x${descMap.attrId} (value ${descMap.value})" // rbn.xiaomi#L158
            break // rbn.xiaomi#L159
    } // rbn.xiaomi#L160
} // rbn.xiaomi#L161

public void parseXiaomiClusterTags(final Map<Integer, Object> tags) { // rbn.xiaomi#L164
    final String funcName = 'parseXiaomiClusterTags' // rbn.xiaomi#L165
    tags.each { final Integer tag, final Object value -> // rbn.xiaomi#L166
        parseXiaomiClusterSingeTag(tag, value) // rbn.xiaomi#L167
    } // rbn.xiaomi#L168
} // rbn.xiaomi#L169

public void parseXiaomiClusterSingeTag(final Integer tag, final Object value) { // rbn.xiaomi#L171
    final String funcName = 'parseXiaomiClusterSingeTag' // rbn.xiaomi#L172
    switch (tag) { // rbn.xiaomi#L173
        case 0x01: // rbn.xiaomi#L174
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} battery voltage is ${value / 1000}V (raw=${value})" // rbn.xiaomi#L175
            break // rbn.xiaomi#L176
        case 0x03: // rbn.xiaomi#L177
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} device temperature is ${value}&deg;" // rbn.xiaomi#L178
            break // rbn.xiaomi#L179
        case 0x05: // rbn.xiaomi#L180
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} RSSI is ${value}" // rbn.xiaomi#L181
            break // rbn.xiaomi#L182
        case 0x06: // rbn.xiaomi#L183
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} LQI is ${value}" // rbn.xiaomi#L184
            break // rbn.xiaomi#L185
        case 0x08: // rbn.xiaomi#L186
            final String swBuild = '0.0.0_' + (value & 0xFF).toString().padLeft(4, '0') // rbn.xiaomi#L187
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} swBuild is ${swBuild} (raw ${value})" // rbn.xiaomi#L188
            device.updateDataValue('aqaraVersion', swBuild) // rbn.xiaomi#L189
            break // rbn.xiaomi#L190
        case 0x0a: // rbn.xiaomi#L191
            String nwk = intToHexStr(value as Integer, 2) // rbn.xiaomi#L192
            if (state.health == null) { state.health = [:] } // rbn.xiaomi#L193
            String oldNWK = state.health['parentNWK'] ?: 'n/a' // rbn.xiaomi#L194
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} <b>Parent NWK is ${nwk}</b>" // rbn.xiaomi#L195
            if (oldNWK != nwk ) { // rbn.xiaomi#L196
                logWarn "parentNWK changed from ${oldNWK} to ${nwk}" // rbn.xiaomi#L197
                state.health['parentNWK']  = nwk // rbn.xiaomi#L198
                state.health['nwkCtr'] = (state.health['nwkCtr'] ?: 0) + 1 // rbn.xiaomi#L199
            } // rbn.xiaomi#L200
            break // rbn.xiaomi#L201
        case 0x0b: // rbn.xiaomi#L202
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} light level is ${value}" // rbn.xiaomi#L203
            break // rbn.xiaomi#L204
        case 0x64: // rbn.xiaomi#L205
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} temperature is ${value / 100} (raw ${value})" // rbn.xiaomi#L206

            break // rbn.xiaomi#L208
        case 0x65: // rbn.xiaomi#L209
            if (isAqaraFP1()) { logDebug "${funcName} PRESENCE_TAG_ID tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L210
            else              { logDebug "xiaomi decode tag: 0x${intToHexStr(tag, 1)} humidity is ${value / 100} (raw ${value})" } // rbn.xiaomi#L211
            break // rbn.xiaomi#L212
        case 0x66: // rbn.xiaomi#L213
            if (isAqaraFP1()) { logDebug "${funcName} SENSITIVITY_LEVEL_TAG_ID tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L214
            else if (isAqaraTVOC_Lib()) { logDebug "xiaomi decode tag: 0x${intToHexStr(tag, 1)} airQualityIndex is ${value}" } // rbn.xiaomi#L215
            else                    { logDebug "xiaomi decode tag: 0x${intToHexStr(tag, 1)} presure is ${value}" } // rbn.xiaomi#L216
            break // rbn.xiaomi#L217
        case 0x67: // rbn.xiaomi#L218
            if (isAqaraFP1()) { logDebug "${funcName} DIRECTION_MODE_TAG_ID tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L219
            else              { logDebug "${funcName} unknown tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L220

            break // rbn.xiaomi#L222
        case 0x69: // rbn.xiaomi#L223
            if (isAqaraFP1()) { logDebug "${funcName} TRIGGER_DISTANCE_TAG_ID tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L224
            else              { logDebug "${funcName} unknown tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L225
            break // rbn.xiaomi#L226
        case 0x6a: // rbn.xiaomi#L227
            if (isAqaraFP1()) { logDebug "${funcName} FP1 unknown tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L228
            else              { logDebug "${funcName} MOTION SENSITIVITY tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L229
            break // rbn.xiaomi#L230
        case 0x6b: // rbn.xiaomi#L231
            if (isAqaraFP1()) { logDebug "${funcName} FP1 unknown tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L232
            else              { logDebug "${funcName} MOTION LED tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L233
            break // rbn.xiaomi#L234
        case 0x95: // rbn.xiaomi#L235
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} energy is ${value}" // rbn.xiaomi#L236
            break // rbn.xiaomi#L237
        case 0x96: // rbn.xiaomi#L238
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} voltage is ${value}" // rbn.xiaomi#L239
            break // rbn.xiaomi#L240
        case 0x97: // rbn.xiaomi#L241
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} current is ${value}" // rbn.xiaomi#L242
            break // rbn.xiaomi#L243
        case 0x98: // rbn.xiaomi#L244
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} power is ${value}" // rbn.xiaomi#L245
            break // rbn.xiaomi#L246
        case 0x9b: // rbn.xiaomi#L247
            if (isAqaraCube()) { // rbn.xiaomi#L248
                logDebug "${funcName} Aqara cubeMode tag: 0x${intToHexStr(tag, 1)} is '${AqaraCubeModeOpts.options[value as int]}' (${value})" // rbn.xiaomi#L249
                sendAqaraCubeOperationModeEvent(value as int) // rbn.xiaomi#L250
            } // rbn.xiaomi#L251
            else { logDebug "${funcName} CONSUMER CONNECTED tag: 0x${intToHexStr(tag, 1)}=${value}" } // rbn.xiaomi#L252
            break // rbn.xiaomi#L253
        default: // rbn.xiaomi#L254
            logDebug "${funcName} unknown tag: 0x${intToHexStr(tag, 1)}=${value}" // rbn.xiaomi#L255
    } // rbn.xiaomi#L256
} // rbn.xiaomi#L257

private static BigInteger readBigIntegerBytes(final ByteArrayInputStream stream, final int length) { // rbn.xiaomi#L263
    final byte[] byteArr = new byte[length] // rbn.xiaomi#L264
    stream.read(byteArr, 0, length) // rbn.xiaomi#L265
    BigInteger bigInt = BigInteger.ZERO // rbn.xiaomi#L266
    for (int i = byteArr.length - 1; i >= 0; i--) { // rbn.xiaomi#L267
        bigInt |= (BigInteger.valueOf((byteArr[i] & 0xFF) << (8 * i))) // rbn.xiaomi#L268
    } // rbn.xiaomi#L269
    return bigInt // rbn.xiaomi#L270
} // rbn.xiaomi#L271

private Map<Integer, Object> decodeXiaomiTags(final String hexString) { // rbn.xiaomi#L278
    try { // rbn.xiaomi#L279
        final Map<Integer, Object> results = [:] // rbn.xiaomi#L280
        final byte[] bytes = HexUtils.hexStringToByteArray(hexString) // rbn.xiaomi#L281
        new ByteArrayInputStream(bytes).withCloseable { final stream -> // rbn.xiaomi#L282
            while (stream.available() > 2) { // rbn.xiaomi#L283
                int tag = stream.read() // rbn.xiaomi#L284
                int dataType = stream.read() // rbn.xiaomi#L285
                Object value // rbn.xiaomi#L286
                if (DataType.isDiscrete(dataType)) { // rbn.xiaomi#L287
                    int length = stream.read() // rbn.xiaomi#L288
                    byte[] byteArr = new byte[length] // rbn.xiaomi#L289
                    stream.read(byteArr, 0, length) // rbn.xiaomi#L290
                    value = new String(byteArr) // rbn.xiaomi#L291
                } else { // rbn.xiaomi#L292
                    int length = DataType.getLength(dataType) // rbn.xiaomi#L293
                    value = readBigIntegerBytes(stream, length) // rbn.xiaomi#L294
                } // rbn.xiaomi#L295
                results[tag] = value // rbn.xiaomi#L296
            } // rbn.xiaomi#L297
        } // rbn.xiaomi#L298
        return results // rbn.xiaomi#L299
    } // rbn.xiaomi#L300
    catch (e) { // rbn.xiaomi#L301
        if (settings.logEnable) { "${device.displayName} decodeXiaomiTags: ${e}" } // rbn.xiaomi#L302
        return [:] // rbn.xiaomi#L303
    } // rbn.xiaomi#L304
} // rbn.xiaomi#L305

List<String> refreshXiaomi() { // rbn.xiaomi#L307
    List<String> cmds = [] // rbn.xiaomi#L308
    if (cmds == []) { cmds = ['delay 299'] } // rbn.xiaomi#L309
    return cmds // rbn.xiaomi#L310
} // rbn.xiaomi#L311

List<String> configureXiaomi() { // rbn.xiaomi#L313
    List<String> cmds = [] // rbn.xiaomi#L314
    logDebug "configureXiaomi() : ${cmds}" // rbn.xiaomi#L315
    if (cmds == []) { cmds = ['delay 299'] } // rbn.xiaomi#L316
    return cmds // rbn.xiaomi#L317
} // rbn.xiaomi#L318

List<String> initializeXiaomi() { // rbn.xiaomi#L320
    List<String> cmds = [] // rbn.xiaomi#L321
    logDebug "initializeXiaomi() : ${cmds}" // rbn.xiaomi#L322
    if (cmds == []) { cmds = ['delay 299',] } // rbn.xiaomi#L323
    return cmds // rbn.xiaomi#L324
} // rbn.xiaomi#L325

void initVarsXiaomi(boolean fullInit=false) { // rbn.xiaomi#L327
    logDebug "initVarsXiaomi(${fullInit})" // rbn.xiaomi#L328
} // rbn.xiaomi#L329

void initEventsXiaomi(boolean fullInit=false) { // rbn.xiaomi#L331
    logDebug "initEventsXiaomi(${fullInit})" // rbn.xiaomi#L332
} // rbn.xiaomi#L333

List<String> standardAqaraBlackMagic() { // rbn.xiaomi#L335
    return [] // rbn.xiaomi#L336

    List<String> cmds = [] // rbn.xiaomi#L338
    if (isAqaraTVOC_OLD() || isAqaraTRV_OLD()) { // rbn.xiaomi#L339
        cmds += ["he raw 0x${device.deviceNetworkId} 0 0 0x8002 {40 00 00 00 00 40 8f 5f 11 52 52 00 41 2c 52 00 00} {0x0000}", 'delay 200',] // rbn.xiaomi#L340
        cmds += "zdo bind 0x${device.deviceNetworkId} 0x01 0x01 0xFCC0 {${device.zigbeeId}} {}" // rbn.xiaomi#L341
        cmds += "zdo bind 0x${device.deviceNetworkId} 0x01 0x01 0x0406 {${device.zigbeeId}} {}" // rbn.xiaomi#L342
        cmds += zigbee.readAttribute(0x0001, 0x0020, [:], delay = 200) // rbn.xiaomi#L343
        if (isAqaraTVOC_OLD()) { // rbn.xiaomi#L344
            cmds += zigbee.readAttribute(0xFCC0, [0x0102, 0x010C], [mfgCode: 0x115F], delay = 200) // rbn.xiaomi#L345
        } // rbn.xiaomi#L346
        logDebug 'standardAqaraBlackMagic()' // rbn.xiaomi#L347
    } // rbn.xiaomi#L348
    return cmds // rbn.xiaomi#L349
} // rbn.xiaomi#L350
// ~~~~~ end include rbn.xiaomi ~~~~~

// ~~~~~ start include rbn.button ~~~~~
library( // rbn.button#L2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee Button Library', name: 'button', namespace: 'rbn', // rbn.button#L3
    importUrl: '', documentationLink: '', // rbn.button#L4
    version: '3.2.0' // rbn.button#L5
) // rbn.button#L6
/*
 *  Zigbee Button Library
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
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/buttonLib.groovy) at commit 0bf47407.
 *  Modified for the rbn namespace: identity changes only.
 *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/button.groovy#L22-L25
*/

static String buttonLibVersion()   { '3.2.0' } // rbn.button#L28
static String buttonLibStamp() { '2024/05/24 12:48 PM' } // rbn.button#L29

metadata { // rbn.button#L31
    capability 'PushableButton' // rbn.button#L32
    capability 'Momentary' // rbn.button#L33

    preferences { // rbn.button#L42

    } // rbn.button#L44
} // rbn.button#L45

void sendButtonEvent(int buttonNumber, String buttonState, boolean isDigital=false) { // rbn.button#L47
    if (buttonState != 'unknown' && buttonNumber != 0) { // rbn.button#L48
        String descriptionText = "button $buttonNumber was $buttonState" // rbn.button#L49
        if (isDigital) { descriptionText += ' [digital]' } // rbn.button#L50
        Map event = [name: buttonState, value: buttonNumber.toString(), data: [buttonNumber: buttonNumber], descriptionText: descriptionText, isStateChange: true, type: isDigital == true ? 'digital' : 'physical'] // rbn.button#L51
        logInfo "$descriptionText" // rbn.button#L52
        sendEvent(event) // rbn.button#L53
    } // rbn.button#L54
    else { // rbn.button#L55
        logWarn "sendButtonEvent: UNHANDLED event for button ${buttonNumber}, buttonState=${buttonState}" // rbn.button#L56
    } // rbn.button#L57
} // rbn.button#L58

void push() { // rbn.button#L60
    logDebug 'push momentary' // rbn.button#L61
    if (this.respondsTo('customPush')) { customPush(); return } // rbn.button#L62
    logWarn "push() not implemented for ${(DEVICE_TYPE)}" // rbn.button#L63
} // rbn.button#L64

void push(Object bn) { // rbn.button#L74
    Integer buttonNumber = bn.toInteger() // rbn.button#L75
    logDebug "push button $buttonNumber" // rbn.button#L76
    if (this.respondsTo('customPush')) { customPush(buttonNumber); return } // rbn.button#L77
    sendButtonEvent(buttonNumber as int, 'pushed', isDigital = true) // rbn.button#L78
} // rbn.button#L79

void doubleTap(Object bn) { // rbn.button#L81
    Integer buttonNumber = bn.toInteger() // rbn.button#L82
    sendButtonEvent(buttonNumber as int, 'doubleTapped', isDigital = true) // rbn.button#L83
} // rbn.button#L84

void hold(Object bn) { // rbn.button#L86
    Integer buttonNumber = bn.toInteger() // rbn.button#L87
    sendButtonEvent(buttonNumber as int, 'held', isDigital = true) // rbn.button#L88
} // rbn.button#L89

void release(Object bn) { // rbn.button#L91
    Integer buttonNumber = bn.toInteger() // rbn.button#L92
    sendButtonEvent(buttonNumber as int, 'released', isDigital = true) // rbn.button#L93
} // rbn.button#L94

void sendNumberOfButtonsEvent(int numberOfButtons) { // rbn.button#L97
    sendEvent(name: 'numberOfButtons', value: numberOfButtons, isStateChange: true, type: 'digital') // rbn.button#L98
} // rbn.button#L99

void sendSupportedButtonValuesEvent(List<String> supportedValues) { // rbn.button#L101
    sendEvent(name: 'supportedButtonValues', value: JsonOutput.toJson(supportedValues), isStateChange: true, type: 'digital') // rbn.button#L102
} // rbn.button#L103
// ~~~~~ end include rbn.button ~~~~~

// ~~~~~ start include rbn.battery ~~~~~
library( // rbn.battery#L2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee Battery Library', name: 'battery', namespace: 'rbn', // rbn.battery#L3
    importUrl: '', documentationLink: '', // rbn.battery#L4
    version: '3.2.4' // rbn.battery#L5
) // rbn.battery#L6
/*
 *  Zigbee Battery Library
 *
 *  Licensed Virtual the Apache License, Version 2.0
 *
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/batteryLib.groovy) at commit 0bf47407.
 *  Modified for the rbn namespace: isTuya() branch and Tuya battery-level helpers removed; identity.
 *  Changelog: https://github.com/jmuchovej/homelab/blob/main/hubitat/libraries/battery.groovy#L15-L25
*/

static String batteryLibVersion()   { '3.2.4' } // rbn.battery#L28
static String batteryLibStamp() { '2026/08/23 3:43 PM' } // rbn.battery#L29

metadata { // rbn.battery#L31
    capability 'Battery' // rbn.battery#L32
    attribute  'batteryVoltage', 'number' // rbn.battery#L33
    attribute  'lastBattery', 'date' // rbn.battery#L34

    preferences { // rbn.battery#L36
        if (device && advancedOptions == true) { // rbn.battery#L37
            if ('BatteryVoltage' in DEVICE?.capabilities) { // rbn.battery#L38
                input name: 'voltageToPercent', type: 'bool', title: '<b>Battery Voltage to Percentage</b>', defaultValue: false, description: 'Convert battery voltage to battery Percentage remaining.' // rbn.battery#L39
            } // rbn.battery#L40
            if ('BatteryDelay' in DEVICE?.capabilities) { // rbn.battery#L41
                input(name: 'batteryDelay', type: 'enum', title: '<b>Battery Events Delay</b>', description:'Select the Battery Events Delay<br>(default is <b>no delay</b>)', options: DelayBatteryOpts.options, defaultValue: DelayBatteryOpts.defaultValue) // rbn.battery#L42
            } // rbn.battery#L43
        } // rbn.battery#L44
    } // rbn.battery#L45
} // rbn.battery#L46

@Field static final Map DelayBatteryOpts = [ defaultValue: 0, options: [0: 'No delay', 30: '30 seconds', 3600: '1 hour', 14400: '4 hours', 28800: '8 hours', 43200: '12 hours']] // rbn.battery#L48

public void standardParsePowerCluster(final Map descMap) { // rbn.battery#L50
    if (descMap.value == null || descMap.value == 'FFFF') { return } // rbn.battery#L51
    final int rawValue = hexStrToUnsignedInt(descMap.value) // rbn.battery#L52
    if (descMap.attrId == '0020') { // rbn.battery#L53
        state.lastRx['batteryTime'] = new Date().getTime() // rbn.battery#L54
        state.stats['bVoltCtr'] = (state.stats['bVoltCtr'] ?: 0) + 1 // rbn.battery#L55
        sendBatteryVoltageEvent(rawValue) // rbn.battery#L56
        if ((settings.voltageToPercent ?: false) == true) { // rbn.battery#L57
            sendBatteryVoltageEvent(rawValue, convertToPercent = true) // rbn.battery#L58
        } // rbn.battery#L59
    } // rbn.battery#L60
    else if (descMap.attrId == '0021') { // rbn.battery#L61
        state.lastRx['batteryTime'] = new Date().getTime() // rbn.battery#L62
        state.stats['battCtr'] = (state.stats['battCtr'] ?: 0) + 1 // rbn.battery#L63
        sendBatteryPercentageEvent(Math.round(rawValue / 2.0) as int) // rbn.battery#L64
    } // rbn.battery#L65
    else { // rbn.battery#L66
        logWarn "customParsePowerCluster: zigbee received unknown Power cluster attribute 0x${descMap.attrId} (value ${descMap.value})" // rbn.battery#L67
    } // rbn.battery#L68
} // rbn.battery#L69

public void sendBatteryVoltageEvent(final int rawValue, boolean convertToPercent=false) { // rbn.battery#L71
    logDebug "batteryVoltage = ${(double)rawValue / 10.0} V" // rbn.battery#L72
    final Date lastBattery = new Date() // rbn.battery#L73
    Map result = [:] // rbn.battery#L74
    BigDecimal volts = safeToBigDecimal(rawValue) / 10G // rbn.battery#L75
    if (rawValue != 0 && rawValue != 255) { // rbn.battery#L76
        BigDecimal minVolts = 2.2 // rbn.battery#L77
        BigDecimal maxVolts = 3.2 // rbn.battery#L78
        BigDecimal pct = (volts - minVolts) / (maxVolts - minVolts) // rbn.battery#L79
        int roundedPct = Math.round(pct * 100) // rbn.battery#L80
        if (roundedPct <= 0) { roundedPct = 1 } // rbn.battery#L81
        if (roundedPct > 100) { roundedPct = 100 } // rbn.battery#L82
        if (convertToPercent == true) { // rbn.battery#L83
            result.value = Math.min(100, roundedPct) // rbn.battery#L84
            result.name = 'battery' // rbn.battery#L85
            result.unit  = '%' // rbn.battery#L86
            result.descriptionText = "battery is ${roundedPct} %" // rbn.battery#L87
        } // rbn.battery#L88
        else { // rbn.battery#L89
            result.value = volts // rbn.battery#L90
            result.name = 'batteryVoltage' // rbn.battery#L91
            result.unit  = 'V' // rbn.battery#L92
            result.descriptionText = "battery is ${volts} Volts" // rbn.battery#L93
        } // rbn.battery#L94
        result.type = 'physical' // rbn.battery#L95
        result.isStateChange = true // rbn.battery#L96
        logInfo "${result.descriptionText}" // rbn.battery#L97
        sendEvent(result) // rbn.battery#L98
        sendEvent(name: 'lastBattery', value: lastBattery) // rbn.battery#L99
    } // rbn.battery#L100
    else { // rbn.battery#L101
        logWarn "ignoring BatteryResult(${rawValue})" // rbn.battery#L102
    } // rbn.battery#L103
} // rbn.battery#L104

public void sendBatteryPercentageEvent(final int batteryPercent, boolean isDigital=false) { // rbn.battery#L106
    if ((batteryPercent as int) == 255) { // rbn.battery#L107
        logWarn "ignoring battery report raw=${batteryPercent}" // rbn.battery#L108
        return // rbn.battery#L109
    } // rbn.battery#L110
    final Date lastBattery = new Date() // rbn.battery#L111
    Map map = [:] // rbn.battery#L112
    map.name = 'battery' // rbn.battery#L113
    map.timeStamp = now() // rbn.battery#L114
    map.value = batteryPercent < 0 ? 0 : batteryPercent > 100 ? 100 : (batteryPercent as int) // rbn.battery#L115
    map.unit  = '%' // rbn.battery#L116
    map.type = isDigital ? 'digital' : 'physical' // rbn.battery#L117
    map.descriptionText = "${map.name} is ${map.value} ${map.unit}" // rbn.battery#L118
    map.isStateChange = true // rbn.battery#L119

    Object latestBatteryEvent = device.currentState('battery') // rbn.battery#L121
    Long latestBatteryEventTime = latestBatteryEvent != null ? latestBatteryEvent.getDate().getTime() : now() // rbn.battery#L122

    int timeDiff = ((now() - latestBatteryEventTime) / 1000) as int // rbn.battery#L124
    if (settings?.batteryDelay == null || (settings?.batteryDelay as int) == 0 || timeDiff > (settings?.batteryDelay as int)) { // rbn.battery#L125

        sendDelayedBatteryPercentageEvent(map) // rbn.battery#L127
        sendEvent(name: 'lastBattery', value: lastBattery) // rbn.battery#L128
    } // rbn.battery#L129
    else { // rbn.battery#L130
        int delayedTime = (settings?.batteryDelay as int) - timeDiff // rbn.battery#L131
        map.delayed = delayedTime // rbn.battery#L132
        map.descriptionText += " [delayed ${map.delayed} seconds]" // rbn.battery#L133
        map.lastBattery = lastBattery // rbn.battery#L134
        logDebug "this  battery event (${map.value}%) will be delayed ${delayedTime} seconds" // rbn.battery#L135
        runIn(delayedTime, 'sendDelayedBatteryPercentageEvent', [overwrite: true, data: map]) // rbn.battery#L136
    } // rbn.battery#L137
} // rbn.battery#L138

private void sendDelayedBatteryPercentageEvent(Map map) { // rbn.battery#L140
    logInfo "${map.descriptionText}" // rbn.battery#L141

    sendEvent(map) // rbn.battery#L143
    sendEvent(name: 'lastBattery', value: map.lastBattery) // rbn.battery#L144
} // rbn.battery#L145

private void sendDelayedBatteryVoltageEvent(Map map) { // rbn.battery#L148
    logInfo "${map.descriptionText}" // rbn.battery#L149

    sendEvent(map) // rbn.battery#L151
    sendEvent(name: 'lastBattery', value: map.lastBattery) // rbn.battery#L152
} // rbn.battery#L153

public void batteryInitializeVars( boolean fullInit = false ) { // rbn.battery#L155
    logDebug "batteryInitializeVars()... fullInit = ${fullInit}" // rbn.battery#L156
    if (device.hasCapability('Battery')) { // rbn.battery#L157
        if (fullInit || settings?.voltageToPercent == null) { device.updateSetting('voltageToPercent', false) } // rbn.battery#L158
        if (fullInit || settings?.batteryDelay == null) { device.updateSetting('batteryDelay', [value: DelayBatteryOpts.defaultValue.toString(), type: 'enum']) } // rbn.battery#L159
    } // rbn.battery#L160
} // rbn.battery#L161

public List<String> batteryRefresh() { // rbn.battery#L163
    List<String> cmds = [] // rbn.battery#L164
    cmds += zigbee.readAttribute(0x0001, 0x0020, [:], delay = 100) // rbn.battery#L165
    cmds += zigbee.readAttribute(0x0001, 0x0021, [:], delay = 100) // rbn.battery#L166
    return cmds // rbn.battery#L167
} // rbn.battery#L168
// ~~~~~ end include rbn.battery ~~~~~
