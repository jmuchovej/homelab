/* groovylint-disable CompileStatic, DuplicateListLiteral, DuplicateMapLiteral, DuplicateNumberLiteral, DuplicateStringLiteral, ImplicitClosureParameter, ImplicitReturnStatement, InsecureRandom, LineLength, MethodCount, MethodReturnTypeRequired, MethodSize, NglParseError, NoDef, ParameterName, PublicMethodsBeforeNonPublicMethods, StaticMethodsBeforeInstanceMethods, UnnecessaryGetter, UnnecessaryGroovyImport, UnnecessaryObjectReferences, UnnecessaryPackageReference, UnusedImport, UnusedPrivateMethod, VariableName */
/**
 *  Aqara Cube T1 Pro - Device Driver for Hubitat Elevation
 *
 *  https://community.hubitat.com/t/alpha-aqara-cube-t1-pro-mfczq12lm-c-7/121604
 *
 * 	Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
 * 	in compliance with the License. You may obtain a copy of the License at:
 *
 * 		http://www.apache.org/licenses/LICENSE-2.0
 *
 * 	Unless required by applicable law or agreed to in writing, software distributed under the License is distributed
 * 	on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 * 	for the specific language governing permissions and limitations under the License.
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
 *
 *                                   TODO: 
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
    if (fullInit || settings?.voltageToPercent == null) device.updateSetting("voltageToPercent", true)        // overwrite the defailt false setting
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
/* groovylint-disable CompileStatic, DuplicateListLiteral, DuplicateMapLiteral, DuplicateNumberLiteral, DuplicateStringLiteral, ImplicitClosureParameter, ImplicitReturnStatement, InsecureRandom, LineLength, MethodCount, MethodReturnTypeRequired, MethodSize, NglParseError, NoDouble, ParameterName, PublicMethodsBeforeNonPublicMethods, StaticMethodsBeforeInstanceMethods, UnnecessaryGetter, UnnecessaryGroovyImport, UnnecessaryObjectReferences, UnnecessaryPackageReference, UnnecessaryPublicModifier, UnnecessarySetter, UnusedImport, UnusedPrivateMethod, VariableName */ // library marker rbn.common, line 1
library( // library marker rbn.common, line 2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Common ZCL Library', name: 'common', namespace: 'rbn', // library marker rbn.common, line 3
    importUrl: '', documentationLink: '', // library marker rbn.common, line 4
    version: '4.1.1' // library marker rbn.common, line 5
) // library marker rbn.common, line 6
/* // library marker rbn.common, line 7
  *  Common ZCL Library // library marker rbn.common, line 8
  * // library marker rbn.common, line 9
  *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except // library marker rbn.common, line 10
  *  in compliance with the License. You may obtain a copy of the License at: // library marker rbn.common, line 11
  * // library marker rbn.common, line 12
  *      http://www.apache.org/licenses/LICENSE-2.0 // library marker rbn.common, line 13
  * // library marker rbn.common, line 14
  *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed // library marker rbn.common, line 15
  *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License // library marker rbn.common, line 16
  *  for the specific language governing permissions and limitations under the License. // library marker rbn.common, line 17
  * // library marker rbn.common, line 18
  *  Forked from https://github.com/kkossev/Hubitat (Libraries/commonLib.groovy) at commit 0bf47407. // library marker rbn.common, line 19
  *  Modified for the rbn namespace: Tuya code path removed (0xEF00 cluster handling, E00x pre-parsers in parse(), // library marker rbn.common, line 20
  *  Tuya command builders and constants, tuyaTest/tuyaBlackMagic/queryAllTuyaDP, isTuya/updateTuyaVersion); identity. // library marker rbn.common, line 21
  * // library marker rbn.common, line 22
  * This library is inspired by @w35l3y work on Tuya device driver (Edge project). // library marker rbn.common, line 23
  * For a big portions of code all credits go to Jonathan Bradshaw. // library marker rbn.common, line 24
  * // library marker rbn.common, line 25
  * // library marker rbn.common, line 26
  * ver. 1.0.0  2022-06-18 kkossev  - first beta version // library marker rbn.common, line 27
  * .............................. // library marker rbn.common, line 28
  * ver. 3.5.2  2025-08-13 kkossev  - Status attribute renamed to _status_ // library marker rbn.common, line 29
  * ver. 4.0.0  2025-09-17 kkossev  - deviceProfileV4; HOBEIAN as Tuya device; customInitialize() hook; // library marker rbn.common, line 30
  * ver. 4.0.1  2025-10-14 kkossev  - added clusters 0xFC80 and 0xFC81 // library marker rbn.common, line 31
  * ver. 4.0.2  2025-10-18 kkossev  - added tuyaDelay in sendTuyaCommand() // library marker rbn.common, line 32
  * ver. 4.0.3  2025-10-18 kkossev  - added ignoreDuplicatedZigbeeMessages setting; DIGITAL_TIMER increased to 5000 ms // library marker rbn.common, line 33
  * ver. 4.0.4  2026-06-04 kkossev  - added ED00 cluster; // library marker rbn.common, line 34
  * ver. 4.0.5  2026-08-03 kkossev  - bug fixes // library marker rbn.common, line 35
  * ver. 4.1.0  2026-08-05 kkossev  - the administrative commands drop-down moved from configure(par) to the new deviceUtilities(par) command, so that configure() is again a plain Configuration capability button; removed the two separator entries from ConfigureOpts; configureHelp() is callable again and shows the command list and a '_status_' event when nothing was selected; do not use 'defaultValue' in a command parameter - it does not preselect the drop-down, but it IS submitted when Run is pressed without a selection!; configure() now shows a 'sleepy devices can not be configured' warning text; ping() icon changed to the antenna bars; added a one-click 'loadAllDefaults' command button // library marker rbn.common, line 36
  * ver. 4.1.1  2026-08-23 kkossev  - (dev. branch) bug fix: quoted the respondsTo('processTuyaDPfromDeviceProfile') argument in standardProcessTuyaDP(); the bare identifier threw a NullPointerException in drivers without deviceProfileLib; cosmetic: parse() and standardAndCustomParseCluster() log the cluster id from clusterId/clusterInt when descMap.cluster is null (catchall messages), instead of 'cluster:0xnull'; removed a stray '}' from the healthStatus warning text // library marker rbn.common, line 37
  * // library marker rbn.common, line 38
  *                                   TODO: change the offline threshold to 2  // library marker rbn.common, line 39
  *                                   TODO: add GetInfo (endpoints list) command (in the 'Tuya Device' driver?) // library marker rbn.common, line 40
  *                                   TODO: make the configure() without parameter smart - analyze the State variables and call delete states.... call ActiveAndpoints() or/amd initialize() or/and configure() // library marker rbn.common, line 41
  *                                   TODO: check - offlineCtr is not increasing? (ZBMicro); // library marker rbn.common, line 42
  *                                   TODO: check deviceCommandTimeout() // library marker rbn.common, line 43
  *                                   TODO: when device rejoins the network, read the battery percentage again (probably in custom handler, not for all devices) // library marker rbn.common, line 44
  *                                   TODO: refresh() to include updating the softwareBuild data version // library marker rbn.common, line 45
  *                                   TODO: map the ZCL powerSource options to Hubitat powerSource options // library marker rbn.common, line 46
  *                                   TODO: MOVE ZDO counters to health state? // library marker rbn.common, line 47
  *                                   TODO: refresh() to bypass the duplicated events and minimim delta time between events checks // library marker rbn.common, line 48
  *                                   TODO: Versions of the main module + included libraries (in the 'Tuya Device' driver?) // library marker rbn.common, line 49
  *                                   TODO: disableDefaultResponse for Tuya commands // library marker rbn.common, line 50
  * // library marker rbn.common, line 51
*/ // library marker rbn.common, line 52
 // library marker rbn.common, line 53
String commonLibVersion() { '4.1.1' } // library marker rbn.common, line 54
String commonLibStamp() { '2026/08/23 4:28 PM' } // library marker rbn.common, line 55
 // library marker rbn.common, line 56
import groovy.transform.Field // library marker rbn.common, line 57
import hubitat.device.HubMultiAction // library marker rbn.common, line 58
import hubitat.device.Protocol // library marker rbn.common, line 59
import hubitat.helper.HexUtils // library marker rbn.common, line 60
import hubitat.zigbee.zcl.DataType // library marker rbn.common, line 61
import java.util.concurrent.ConcurrentHashMap // library marker rbn.common, line 62
import groovy.json.JsonOutput // library marker rbn.common, line 63
import groovy.transform.CompileStatic // library marker rbn.common, line 64
import java.math.BigDecimal // library marker rbn.common, line 65
 // library marker rbn.common, line 66
metadata { // library marker rbn.common, line 67
        if (_DEBUG) { // library marker rbn.common, line 68
            command 'test', [[name: 'test', type: 'STRING', description: 'test', defaultValue : '']] // library marker rbn.common, line 69
            command 'testParse', [[name: 'testParse', type: 'STRING', description: 'testParse', defaultValue : '']] // library marker rbn.common, line 70
        } // library marker rbn.common, line 71
 // library marker rbn.common, line 72
        // common capabilities for all device types // library marker rbn.common, line 73
        capability 'Configuration' // library marker rbn.common, line 74
        capability 'Refresh' // library marker rbn.common, line 75
        capability 'HealthCheck' // library marker rbn.common, line 76
        capability 'PowerSource'       // powerSource - ENUM ["battery", "dc", "mains", "unknown"] // library marker rbn.common, line 77
 // library marker rbn.common, line 78
        // common attributes for all device types // library marker rbn.common, line 79
        attribute 'healthStatus', 'enum', ['unknown', 'offline', 'online'] // library marker rbn.common, line 80
        attribute 'rtt', 'number' // library marker rbn.common, line 81
        attribute '_status_', 'string' // library marker rbn.common, line 82
 // library marker rbn.common, line 83
        // common commands for all device types // library marker rbn.common, line 84
        // 'configure' below carries a description-only parameter map (NO 'type' key!), exactly like ping and refresh - it just renders the help text under the button and submits nothing. // library marker rbn.common, line 85
        // NEVER give it a typed parameter: an ENUM here used to shadow the no-argument configure() of capability 'Configuration', making the dispatch depend on whether the platform happened to supply a value. // library marker rbn.common, line 86
        command 'configure', [[name:"✋ This button can not configure battery-powered 'sleepy' devices. Pair the device again to your hub, without deleting it!"]] // library marker rbn.common, line 87
        command 'deviceUtilities', [[name:'⚙️ Advanced administrative and diagnostic commands • Use only when troubleshooting or reconfiguring the device', type: 'ENUM', constraints: ConfigureOpts.keySet() as List<String>]]    // do NOT add a 'defaultValue' here! The drop-down still displays '- No selection -', but the platform submits the defaultValue when Run is pressed - i.e. an un-selected Run silently executed 'LOAD ALL DEFAULTS' (tested on C-8 Pro 2.5.1.143) // library marker rbn.common, line 88
        // one-click shortcut for the most used deviceUtilities entry. Description-only parameter map again - NEVER give loadAllDefaults a typed parameter: deviceUtilities dispatches it as "$func"() with no arguments, so an un-selected Run would hit the no-argument overload and wipe the device immediately. // library marker rbn.common, line 89
        command 'loadAllDefaults', [[name:'⚠️ Erases all preferences, states, scheduled jobs and child devices, then reloads the driver defaults • Use after switching drivers, or when the device was not recognised by an older version']] // library marker rbn.common, line 90
        command 'ping', [[name:'📶 Test device connectivity and measure response time • Updates the RTT attribute with round-trip time in milliseconds']] // library marker rbn.common, line 91
        command 'refresh', [[name:"🔄 Query the device for current state and update the attributes. • ⚠️ Battery-powered 'sleepy' devices may not respond!"]] // library marker rbn.common, line 92
 // library marker rbn.common, line 93
        // trap for Hubitat F2 bug // library marker rbn.common, line 94
        fingerprint profileId:'0104', endpointId:'F2', inClusters:'', outClusters:'', model:'unknown', manufacturer:'unknown', deviceJoinName: 'Zigbee device affected by Hubitat F2 bug' // library marker rbn.common, line 95
 // library marker rbn.common, line 96
    preferences { // library marker rbn.common, line 97
        // txtEnable and logEnable moved to the custom driver settings - copy& paste there ... // library marker rbn.common, line 98
        //input name: 'txtEnable', type: 'bool', title: '<b>Enable descriptionText logging</b>', defaultValue: true, description: '<i>Enables command logging.' // library marker rbn.common, line 99
        //input name: 'logEnable', type: 'bool', title: '<b>Enable debug logging</b>', defaultValue: true, description: 'Turns on debug logging for 24 hours.' // library marker rbn.common, line 100
 // library marker rbn.common, line 101
        if (device) { // library marker rbn.common, line 102
            input name: 'advancedOptions', type: 'bool', title: '<b>Advanced Options</b>', description: 'The advanced options should be already automatically set in an optimal way for your device...Click on the "Save and Close" button when toggling this option!', defaultValue: false // library marker rbn.common, line 103
            if (advancedOptions == true) { // library marker rbn.common, line 104
                input name: 'healthCheckMethod', type: 'enum', title: '<b>Healthcheck Method</b>', options: HealthcheckMethodOpts.options, defaultValue: HealthcheckMethodOpts.defaultValue, required: true, description: 'Method to check device online/offline status.' // library marker rbn.common, line 105
                input name: 'healthCheckInterval', type: 'enum', title: '<b>Healthcheck Interval</b>', options: HealthcheckIntervalOpts.options, defaultValue: HealthcheckIntervalOpts.defaultValue, required: true, description: 'How often the hub will check the device health.<br>3 consecutive failures will result in status "offline"' // library marker rbn.common, line 106
                input name: 'ignoreDuplicatedZigbeeMessages', type: 'bool', title: '<b>Ignore Duplicated Zigbee Messages</b>', defaultValue: false, description: 'Ignore identical Zigbee attribute reports received within short time periods to reduce log spam and redundant processing' // library marker rbn.common, line 107
                input name: 'traceEnable', type: 'bool', title: '<b>Enable trace logging</b>', defaultValue: false, description: 'Turns on detailed extra trace logging for 30 minutes.' // library marker rbn.common, line 108
            } // library marker rbn.common, line 109
        } // library marker rbn.common, line 110
    } // library marker rbn.common, line 111
} // library marker rbn.common, line 112
 // library marker rbn.common, line 113
@Field static final Integer IGNORE_DUPLICATED_ZIGBEE_MESSAGES_TIMER = 1000  // 1 second // library marker rbn.common, line 114
@Field static final Integer DIGITAL_TIMER = 5000             // command was sent by this driver // library marker rbn.common, line 115
@Field static final Integer REFRESH_TIMER = 6000             // refresh time in miliseconds // library marker rbn.common, line 116
@Field static final Integer DEBOUNCING_TIMER = 300           // ignore switch events // library marker rbn.common, line 117
@Field static final Integer COMMAND_TIMEOUT = 10             // timeout time in seconds // library marker rbn.common, line 118
@Field static final Integer MAX_PING_MILISECONDS = 10000     // rtt more than 10 seconds will be ignored // library marker rbn.common, line 119
@Field static final String  UNKNOWN = 'UNKNOWN' // library marker rbn.common, line 120
@Field static final Integer DEFAULT_MIN_REPORTING_TIME = 10  // send the report event no more often than 10 seconds by default // library marker rbn.common, line 121
@Field static final Integer DEFAULT_MAX_REPORTING_TIME = 3600 // library marker rbn.common, line 122
@Field static final Integer PRESENCE_COUNT_THRESHOLD = 3     // missing 3 checks will set the device healthStatus to offline // library marker rbn.common, line 123
@Field static final int DELAY_MS = 200                       // Delay in between zigbee commands // library marker rbn.common, line 124
@Field static final Integer INFO_AUTO_CLEAR_PERIOD = 60      // automatically clear the Info attribute after 60 seconds // library marker rbn.common, line 125
 // library marker rbn.common, line 126
@Field static final Map HealthcheckMethodOpts = [            // used by healthCheckMethod // library marker rbn.common, line 127
    defaultValue: 1, options: [0: 'Disabled', 1: 'Activity check', 2: 'Periodic polling'] // library marker rbn.common, line 128
] // library marker rbn.common, line 129
@Field static final Map HealthcheckIntervalOpts = [          // used by healthCheckInterval // library marker rbn.common, line 130
    defaultValue: 240, options: [2: 'Every 2 Mins', 10: 'Every 10 Mins', 30: 'Every 30 Mins', 60: 'Every 1 Hour', 240: 'Every 4 Hours', 720: 'Every 12 Hours'] // library marker rbn.common, line 131
] // library marker rbn.common, line 132
 // library marker rbn.common, line 133
@Field static final Map ConfigureOpts = [ // library marker rbn.common, line 134
    '*** LOAD ALL DEFAULTS ***'  : [key:0, function: 'loadAllDefaults'], // library marker rbn.common, line 135
    'Configure the device'       : [key:2, function: 'configureNow'], // library marker rbn.common, line 136
    'Reset Statistics'           : [key:9, function: 'resetStatistics'], // library marker rbn.common, line 137
    'Delete All Preferences'     : [key:4, function: 'deleteAllSettings'], // library marker rbn.common, line 138
    'Delete All Current States'  : [key:5, function: 'deleteAllCurrentStates'], // library marker rbn.common, line 139
    'Delete All Scheduled Jobs'  : [key:6, function: 'deleteAllScheduledJobs'], // library marker rbn.common, line 140
    'Delete All State Variables' : [key:7, function: 'deleteAllStates'], // library marker rbn.common, line 141
    'Delete All Child Devices'   : [key:8, function: 'deleteAllChildDevices'] // library marker rbn.common, line 142
] // library marker rbn.common, line 143
 // library marker rbn.common, line 144
public boolean isVirtual() { device.controllerType == null || device.controllerType == '' } // library marker rbn.common, line 145
 // library marker rbn.common, line 146
/** // library marker rbn.common, line 147
 * Parse Zigbee message // library marker rbn.common, line 148
 * @param description Zigbee message in hex format // library marker rbn.common, line 149
 */ // library marker rbn.common, line 150
public void parse(final String description) { // library marker rbn.common, line 151
     // library marker rbn.common, line 152
    Map stateCopy = state            // .clone() throws java.lang.CloneNotSupportedException in HE platform version 2.4.1.155 ! // library marker rbn.common, line 153
    checkDriverVersion(stateCopy)    // +1 ms // library marker rbn.common, line 154
    if (state.stats != null) { state.stats?.rxCtr= (state.stats?.rxCtr ?: 0) + 1 } else { state.stats = [:] }  // updateRxStats(state) // +1 ms // library marker rbn.common, line 155
    if (state.lastRx != null) { state.lastRx?.timeStamp = unix2formattedDate(now()) } else { state.lastRx = [:] } // library marker rbn.common, line 156
    unscheduleCommandTimeoutCheck(state) // library marker rbn.common, line 157
    setHealthStatusOnline(state)    // +2 ms // library marker rbn.common, line 158
 // library marker rbn.common, line 159
    if (description?.startsWith('zone status')  || description?.startsWith('zone report')) { // library marker rbn.common, line 160
        logDebug "parse: zone status: $description" // library marker rbn.common, line 161
        if (this.respondsTo('customParseIasMessage')) { customParseIasMessage(description) } // library marker rbn.common, line 162
        else if (this.respondsTo('standardParseIasMessage')) { standardParseIasMessage(description) } // library marker rbn.common, line 163
        else if (this.respondsTo('parseIasMessage')) { parseIasMessage(description) } // library marker rbn.common, line 164
        else { logDebug "ignored IAS zone status (no IAS parser) description: $description" } // library marker rbn.common, line 165
        return // library marker rbn.common, line 166
    } // library marker rbn.common, line 167
    else if (description?.startsWith('enroll request')) { // library marker rbn.common, line 168
        logDebug "parse: enroll request: $description" // library marker rbn.common, line 169
        /* The Zone Enroll Request command is generated when a device embodying the Zone server cluster wishes to be  enrolled as an active  alarm device. It  must do this immediately it has joined the network  (during commissioning). */ // library marker rbn.common, line 170
        if (settings?.logEnable) { logInfo 'Sending IAS enroll response...' } // library marker rbn.common, line 171
        List<String> cmds = zigbee.enrollResponse() + zigbee.readAttribute(0x0500, 0x0000) // library marker rbn.common, line 172
        logDebug "enroll response: ${cmds}" // library marker rbn.common, line 173
        sendZigbeeCommands(cmds) // library marker rbn.common, line 174
        return // library marker rbn.common, line 175
    } // library marker rbn.common, line 176
 // library marker rbn.common, line 177
    final Map descMap = myParseDescriptionAsMap(description)    // +5 ms // library marker rbn.common, line 178
 // library marker rbn.common, line 179
    if (!isChattyDeviceReport(descMap)) { logDebug "parse: descMap = ${descMap} description=${description }" } // library marker rbn.common, line 180
    if (isSpammyDeviceReport(descMap)) { return }  // +20 mS (both) // library marker rbn.common, line 181
 // library marker rbn.common, line 182
    if (descMap.profileId == '0000') { // library marker rbn.common, line 183
        parseZdoClusters(descMap) // library marker rbn.common, line 184
        return // library marker rbn.common, line 185
    } // library marker rbn.common, line 186
    if (descMap.isClusterSpecific == false) { // library marker rbn.common, line 187
        parseGeneralCommandResponse(descMap) // library marker rbn.common, line 188
        return // library marker rbn.common, line 189
    } // library marker rbn.common, line 190
    // // library marker rbn.common, line 191
    if (standardAndCustomParseCluster(descMap, description)) { return } // library marker rbn.common, line 192
    // // library marker rbn.common, line 193
    switch (descMap.clusterInt as Integer) { // library marker rbn.common, line 194
        case 0x000C :  // special case : ZigUSB                                     // Aqara TVOC Air Monitor; Aqara Cube T1 Pro; // library marker rbn.common, line 195
            if (this.respondsTo('customParseAnalogInputClusterDescription')) { // library marker rbn.common, line 196
                customParseAnalogInputClusterDescription(descMap, description)                 // ZigUSB // library marker rbn.common, line 197
                descMap.remove('additionalAttrs')?.each { final Map map -> customParseAnalogInputClusterDescription(descMap + map, description) } // library marker rbn.common, line 198
            } // library marker rbn.common, line 199
            break // library marker rbn.common, line 200
        case 0x0300 :  // Patch - need refactoring of the standardParseColorControlCluster ! // library marker rbn.common, line 201
            if (this.respondsTo('standardParseColorControlCluster')) { // library marker rbn.common, line 202
                standardParseColorControlCluster(descMap, description) // library marker rbn.common, line 203
                descMap.remove('additionalAttrs')?.each { final Map map -> standardParseColorControlCluster(descMap + map, description) } // library marker rbn.common, line 204
            } // library marker rbn.common, line 205
            break // library marker rbn.common, line 206
        default: // library marker rbn.common, line 207
            if (settings.logEnable) { // library marker rbn.common, line 208
                // descMap.cluster is null for catchall messages - fall back to clusterId, or format clusterInt // library marker rbn.common, line 209
                String clusterHex = descMap.cluster ?: descMap.clusterId ?: zigbee.convertToHexString(descMap.clusterInt as Integer, 4) // library marker rbn.common, line 210
                logWarn "parse: zigbee received <b>unknown cluster:0x${clusterHex} (${descMap.clusterInt})</b> message (${descMap})" // library marker rbn.common, line 211
            } // library marker rbn.common, line 212
            break // library marker rbn.common, line 213
    } // library marker rbn.common, line 214
} // library marker rbn.common, line 215
 // library marker rbn.common, line 216
@Field static final Map<Integer, String> ClustersMap = [ // library marker rbn.common, line 217
    0x0000: 'Basic',             0x0001: 'Power',            0x0003: 'Identify',         0x0004: 'Groups',           0x0005: 'Scenes',       0x0006: 'OnOff',           0x0007:'onOffConfiguration',      0x0008: 'LevelControl',  // library marker rbn.common, line 218
    0x000C: 'AnalogInput',       0x0012: 'MultistateInput',  0x0020: 'PollControl',      0x0102: 'WindowCovering',   0x0201: 'Thermostat',  0x0204: 'ThermostatConfig',/*0x0300: 'ColorControl',*/ // library marker rbn.common, line 219
    0x0400: 'Illuminance',       0x0402: 'Temperature',      0x0405: 'Humidity',         0x0406: 'Occupancy',        0x042A: 'Pm25',         0x0500: 'IAS',             0x0702: 'Metering', // library marker rbn.common, line 220
    0x0B04: 'ElectricalMeasure', 0xE001: 'E0001',            0xE002: 'E002',             0xEC03: 'EC03',             0xFC03: 'FC03',            0xFC11: 'FC11',            0xFC7E: 'AirQualityIndex', // Sensirion VOC index // library marker rbn.common, line 221
    0xFC80: 'FC80',              0xFC81: 'FC81',             0xFCC0: 'XiaomiFCC0',       0xED00: 'ED00' // library marker rbn.common, line 222
] // library marker rbn.common, line 223
 // library marker rbn.common, line 224
// first try calling the custom parser, if not found, call the standard parser // library marker rbn.common, line 225
/* groovylint-disable-next-line UnusedMethodParameter */ // library marker rbn.common, line 226
boolean standardAndCustomParseCluster(Map descMap, final String description) { // library marker rbn.common, line 227
    Integer clusterInt = descMap.clusterInt as Integer // library marker rbn.common, line 228
    String  clusterName = ClustersMap[clusterInt] ?: UNKNOWN // library marker rbn.common, line 229
    // descMap.cluster is null for catchall messages - fall back to clusterId, or format clusterInt, so that the logs never show 'cluster:0xnull' // library marker rbn.common, line 230
    String  clusterHex = descMap.cluster ?: descMap.clusterId ?: zigbee.convertToHexString(clusterInt, 4) // library marker rbn.common, line 231
    if (clusterName == null || clusterName == UNKNOWN) { // library marker rbn.common, line 232
        logWarn "standardAndCustomParseCluster: zigbee received <b>unknown cluster:0x${clusterHex} (${clusterInt})</b> message (${descMap})" // library marker rbn.common, line 233
        return false // library marker rbn.common, line 234
    } // library marker rbn.common, line 235
    String customParser = "customParse${clusterName}Cluster" // library marker rbn.common, line 236
    // check if a custom parser is defined in the custom driver. If found there, the standard parser should  be called within that custom parser, if needed // library marker rbn.common, line 237
    if (this.respondsTo(customParser)) { // library marker rbn.common, line 238
        this."${customParser}"(descMap) // library marker rbn.common, line 239
        descMap.remove('additionalAttrs')?.each { final Map map -> this."${customParser}"(descMap + map) } // library marker rbn.common, line 240
        return true // library marker rbn.common, line 241
    } // library marker rbn.common, line 242
    String standardParser = "standardParse${clusterName}Cluster" // library marker rbn.common, line 243
    // if no custom parser is defined, try the standard parser (if exists), eventually defined in the included library file // library marker rbn.common, line 244
    if (this.respondsTo(standardParser)) { // library marker rbn.common, line 245
        this."${standardParser}"(descMap) // library marker rbn.common, line 246
        descMap.remove('additionalAttrs')?.each { final Map map -> this."${standardParser}"(descMap + map) } // library marker rbn.common, line 247
        return true // library marker rbn.common, line 248
    } // library marker rbn.common, line 249
    if (device?.getDataValue('model') != 'ZigUSB' && descMap.cluster != '0300') {    // patch! // library marker rbn.common, line 250
        logWarn "standardAndCustomParseCluster: <b>Missing</b> ${standardParser} or ${customParser} handler for <b>cluster:0x${clusterHex} (${clusterInt})</b> message (${descMap})" // library marker rbn.common, line 251
    } // library marker rbn.common, line 252
    return false // library marker rbn.common, line 253
} // library marker rbn.common, line 254
 // library marker rbn.common, line 255
// not used - throws exception :  error groovy.lang.MissingPropertyException: No such property: rxCtr for class: java.lang.String on line 1568 (method parse) // library marker rbn.common, line 256
private static void updateRxStats(final Map state) { // library marker rbn.common, line 257
    if (state.stats != null) { state.stats['rxCtr'] = (state.stats['rxCtr'] ?: 0) + 1 } else { state.stats = [:] }  // +5ms // library marker rbn.common, line 258
} // library marker rbn.common, line 259
 // library marker rbn.common, line 260
public boolean isChattyDeviceReport(final Map descMap)  {  // when @CompileStatis is slower? // library marker rbn.common, line 261
    if (_TRACE_ALL == true) { return false } // library marker rbn.common, line 262
    if (this.respondsTo('isSpammyDPsToNotTrace')) {  // defined in deviceProfileLib // library marker rbn.common, line 263
        return isSpammyDPsToNotTrace(descMap) // library marker rbn.common, line 264
    } // library marker rbn.common, line 265
    return false // library marker rbn.common, line 266
} // library marker rbn.common, line 267
 // library marker rbn.common, line 268
public boolean isSpammyDeviceReport(final Map descMap) { // library marker rbn.common, line 269
    if (_TRACE_ALL == true) { return false } // library marker rbn.common, line 270
    if (this.respondsTo('isSpammyDPsToIgnore')) {   // defined in deviceProfileLib // library marker rbn.common, line 271
        return isSpammyDPsToIgnore(descMap) // library marker rbn.common, line 272
    } // library marker rbn.common, line 273
    return false // library marker rbn.common, line 274
} // library marker rbn.common, line 275
 // library marker rbn.common, line 276
@Field static final Map<Integer, String> ZdoClusterEnum = [ // library marker rbn.common, line 277
    0x0002: 'Node Descriptor Request',  0x0005: 'Active Endpoints Request',   0x0006: 'Match Descriptor Request',  0x0022: 'Unbind Request',  0x0013: 'Device announce', 0x0034: 'Management Leave Request', // library marker rbn.common, line 278
    0x8002: 'Node Descriptor Response', 0x8004: 'Simple Descriptor Response', 0x8005: 'Active Endpoints Response', 0x801D: 'Extended Simple Descriptor Response', 0x801E: 'Extended Active Endpoint Response', // library marker rbn.common, line 279
    0x8021: 'Bind Response',            0x8022: 'Unbind Response',            0x8023: 'Bind Register Response',    0x8034: 'Management Leave Response' // library marker rbn.common, line 280
] // library marker rbn.common, line 281
 // library marker rbn.common, line 282
// ZDO (Zigbee Data Object) Clusters Parsing // library marker rbn.common, line 283
private void parseZdoClusters(final Map descMap) { // library marker rbn.common, line 284
    if (state.stats == null) { state.stats = [:] } // library marker rbn.common, line 285
    final Integer clusterId = descMap.clusterInt as Integer // library marker rbn.common, line 286
    final String clusterName = ZdoClusterEnum[clusterId] ?: "UNKNOWN_CLUSTER (0x${descMap.clusterId})" // library marker rbn.common, line 287
    final String statusHex = ((List)descMap.data)[1] // library marker rbn.common, line 288
    final Integer statusCode = hexStrToUnsignedInt(statusHex) // library marker rbn.common, line 289
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${statusHex}" // library marker rbn.common, line 290
    final String clusterInfo = "${device.displayName} Received ZDO ${clusterName} (0x${descMap.clusterId}) status ${statusName}" // library marker rbn.common, line 291
    List<String> cmds = [] // library marker rbn.common, line 292
    switch (clusterId) { // library marker rbn.common, line 293
        case 0x0005 : // library marker rbn.common, line 294
            state.stats['activeEpRqCtr'] = (state.stats['activeEpRqCtr'] ?: 0) + 1 // library marker rbn.common, line 295
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, data:${descMap.data})" } // library marker rbn.common, line 296
            // send the active endpoint response // library marker rbn.common, line 297
            cmds += ["he raw ${device.deviceNetworkId} 0 0 0x8005 {00 00 00 00 01 01} {0x0000}"] // library marker rbn.common, line 298
            sendZigbeeCommands(cmds) // library marker rbn.common, line 299
            break // library marker rbn.common, line 300
        case 0x0006 : // library marker rbn.common, line 301
            state.stats['matchDescCtr'] = (state.stats['matchDescCtr'] ?: 0) + 1 // library marker rbn.common, line 302
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Input cluster count:${descMap.data[5]} Input cluster: 0x${descMap.data[7] + descMap.data[6]})" } // library marker rbn.common, line 303
            cmds += ["he raw ${device.deviceNetworkId} 0 0 0x8006 {00 00 00 00 00} {0x0000}"] // library marker rbn.common, line 304
            sendZigbeeCommands(cmds) // library marker rbn.common, line 305
            break // library marker rbn.common, line 306
        case 0x0013 : // device announcement // library marker rbn.common, line 307
            state.stats['rejoinCtr'] = (state.stats['rejoinCtr'] ?: 0) + 1 // library marker rbn.common, line 308
            if (settings?.logEnable) { log.debug "${clusterInfo}, rejoinCtr= ${state.stats['rejoinCtr']}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Device network ID: ${descMap.data[2] + descMap.data[1]}, Capability Information: ${descMap.data[11]})" } // library marker rbn.common, line 309
            break // library marker rbn.common, line 310
        case 0x8004 : // simple descriptor response // library marker rbn.common, line 311
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, status:${descMap.data[1]}, lenght:${hubitat.helper.HexUtils.hexStringToInt(descMap.data[4])}" } // library marker rbn.common, line 312
            if (this.respondsTo('parseSimpleDescriptorResponse')) { parseSimpleDescriptorResponse(descMap) } // library marker rbn.common, line 313
            break // library marker rbn.common, line 314
        case 0x8005 : // endpoint response // library marker rbn.common, line 315
            String endpointCount = descMap.data[4] // library marker rbn.common, line 316
            String endpointList = descMap.data[5] // library marker rbn.common, line 317
            if (settings?.logEnable) { log.debug "${clusterInfo}, (endpoint response) endpointCount = ${endpointCount}  endpointList = ${endpointList}" } // library marker rbn.common, line 318
            break // library marker rbn.common, line 319
        case 0x8021 : // bind response // library marker rbn.common, line 320
            if (settings?.logEnable) { log.debug "${clusterInfo}, data=${descMap.data} (Sequence Number:${descMap.data[0]}, Status: ${descMap.data[1] == '00' ? 'Success' : '<b>Failure</b>'})" } // library marker rbn.common, line 321
            break // library marker rbn.common, line 322
        case 0x0002 : // Node Descriptor Request // library marker rbn.common, line 323
        case 0x0036 : // Permit Joining Request // library marker rbn.common, line 324
        case 0x8022 : // unbind request // library marker rbn.common, line 325
        case 0x8034 : // leave response // library marker rbn.common, line 326
            if (settings?.logEnable) { log.debug "${device.displayName} Unprocessed ZDO command: cluster=${descMap.clusterId} command=${descMap.command} attrId=${descMap.attrId} value=${descMap.value} data=${descMap.data}" } // library marker rbn.common, line 327
            break // library marker rbn.common, line 328
        default : // library marker rbn.common, line 329
            if (settings?.logEnable) { log.warn "${device.displayName} Unprocessed ZDO command: cluster=${descMap.clusterId} command=${descMap.command} attrId=${descMap.attrId} value=${descMap.value} data=${descMap.data}" } // library marker rbn.common, line 330
            break // library marker rbn.common, line 331
    } // library marker rbn.common, line 332
    if (this.respondsTo('customParseZdoClusters')) { customParseZdoClusters(descMap) } // library marker rbn.common, line 333
} // library marker rbn.common, line 334
 // library marker rbn.common, line 335
// Zigbee General Command Parsing // library marker rbn.common, line 336
private void parseGeneralCommandResponse(final Map descMap) { // library marker rbn.common, line 337
    final int commandId = hexStrToUnsignedInt(descMap.command) // library marker rbn.common, line 338
    switch (commandId) { // library marker rbn.common, line 339
        case 0x01: parseReadAttributeResponse(descMap); break // library marker rbn.common, line 340
        case 0x04: parseWriteAttributeResponse(descMap); break // library marker rbn.common, line 341
        case 0x07: parseConfigureResponse(descMap); break // library marker rbn.common, line 342
        case 0x09: parseReadReportingConfigResponse(descMap); break // library marker rbn.common, line 343
        case 0x0B: parseDefaultCommandResponse(descMap); break // library marker rbn.common, line 344
        default: // library marker rbn.common, line 345
            final String commandName = ZigbeeGeneralCommandEnum[commandId] ?: "UNKNOWN_COMMAND (0x${descMap.command})" // library marker rbn.common, line 346
            final String clusterName = clusterLookup(descMap.clusterInt) // library marker rbn.common, line 347
            final String status = descMap.data in List ? ((List)descMap.data).last() : descMap.data // library marker rbn.common, line 348
            final int statusCode = hexStrToUnsignedInt(status) // library marker rbn.common, line 349
            final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${status}" // library marker rbn.common, line 350
            if (statusCode > 0x00) { // library marker rbn.common, line 351
                log.warn "zigbee ${commandName} ${clusterName} error: ${statusName}" // library marker rbn.common, line 352
            } else if (settings.logEnable) { // library marker rbn.common, line 353
                log.trace "zigbee ${commandName} ${clusterName}: ${descMap.data}" // library marker rbn.common, line 354
            } // library marker rbn.common, line 355
            break // library marker rbn.common, line 356
    } // library marker rbn.common, line 357
} // library marker rbn.common, line 358
 // library marker rbn.common, line 359
// Zigbee Read Attribute Response Parsing // library marker rbn.common, line 360
private void parseReadAttributeResponse(final Map descMap) { // library marker rbn.common, line 361
    final List<String> data = descMap.data as List<String> // library marker rbn.common, line 362
    final String attribute = data[1] + data[0] // library marker rbn.common, line 363
    final int statusCode = hexStrToUnsignedInt(data[2]) // library marker rbn.common, line 364
    final String status = ZigbeeStatusEnum[statusCode] ?: "0x${data}" // library marker rbn.common, line 365
    if (statusCode > 0x00) { // library marker rbn.common, line 366
        logWarn "zigbee read ${clusterLookup(descMap.clusterInt)} attribute 0x${attribute} error: ${status}" // library marker rbn.common, line 367
    } // library marker rbn.common, line 368
    else { // library marker rbn.common, line 369
        logDebug "zigbee read ${clusterLookup(descMap.clusterInt)} attribute 0x${attribute} response: ${status} ${data}" // library marker rbn.common, line 370
    } // library marker rbn.common, line 371
} // library marker rbn.common, line 372
 // library marker rbn.common, line 373
// Zigbee Write Attribute Response Parsing // library marker rbn.common, line 374
private void parseWriteAttributeResponse(final Map descMap) { // library marker rbn.common, line 375
    final String data = descMap.data in List ? ((List)descMap.data).first() : descMap.data // library marker rbn.common, line 376
    final int statusCode = hexStrToUnsignedInt(data) // library marker rbn.common, line 377
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${data}" // library marker rbn.common, line 378
    if (statusCode > 0x00) { // library marker rbn.common, line 379
        logWarn "zigbee response write ${clusterLookup(descMap.clusterInt)} attribute error: ${statusName}" // library marker rbn.common, line 380
    } // library marker rbn.common, line 381
    else { // library marker rbn.common, line 382
        logDebug "zigbee response write ${clusterLookup(descMap.clusterInt)} attribute response: ${statusName}" // library marker rbn.common, line 383
    } // library marker rbn.common, line 384
} // library marker rbn.common, line 385
 // library marker rbn.common, line 386
// Zigbee Configure Reporting Response Parsing  - command 0x07 // library marker rbn.common, line 387
private void parseConfigureResponse(final Map descMap) { // library marker rbn.common, line 388
    // TODO - parse the details of the configuration respose - cluster, min, max, delta ... // library marker rbn.common, line 389
    final String status = ((List)descMap.data).first() // library marker rbn.common, line 390
    final int statusCode = hexStrToUnsignedInt(status) // library marker rbn.common, line 391
    if (statusCode == 0x00 && settings.enableReporting != false) { // library marker rbn.common, line 392
        state.reportingEnabled = true // library marker rbn.common, line 393
    } // library marker rbn.common, line 394
    final String statusName = ZigbeeStatusEnum[statusCode] ?: "0x${status}" // library marker rbn.common, line 395
    if (statusCode > 0x00) { // library marker rbn.common, line 396
        log.warn "zigbee configure reporting error: ${statusName} ${descMap.data}" // library marker rbn.common, line 397
    } else { // library marker rbn.common, line 398
        logDebug "zigbee configure reporting response: ${statusName} ${descMap.data}" // library marker rbn.common, line 399
    } // library marker rbn.common, line 400
} // library marker rbn.common, line 401
 // library marker rbn.common, line 402
// Parses the response of reading reporting configuration - command 0x09 // library marker rbn.common, line 403
private void parseReadReportingConfigResponse(final Map descMap) { // library marker rbn.common, line 404
    int status = zigbee.convertHexToInt(descMap.data[0])    // Status: Success (0x00) // library marker rbn.common, line 405
    //def attr = zigbee.convertHexToInt(descMap.data[3])*256 + zigbee.convertHexToInt(descMap.data[2])    // Attribute: OnOff (0x0000) // library marker rbn.common, line 406
    if (status == 0) { // library marker rbn.common, line 407
        //def dataType = zigbee.convertHexToInt(descMap.data[4])    // Data Type: Boolean (0x10) // library marker rbn.common, line 408
        int min = zigbee.convertHexToInt(descMap.data[6]) * 256 + zigbee.convertHexToInt(descMap.data[5]) // library marker rbn.common, line 409
        int max = zigbee.convertHexToInt(descMap.data[8] + descMap.data[7]) // library marker rbn.common, line 410
        int delta = 0 // library marker rbn.common, line 411
        if (descMap.data.size() >= 11) { // library marker rbn.common, line 412
            delta = zigbee.convertHexToInt(descMap.data[10] + descMap.data[9]) // library marker rbn.common, line 413
        } // library marker rbn.common, line 414
        else if (descMap.data.size() == 10) { // library marker rbn.common, line 415
            delta = zigbee.convertHexToInt(descMap.data[9])      // 1-byte reportable change (uint8/int8) // library marker rbn.common, line 416
        } // library marker rbn.common, line 417
        else { // library marker rbn.common, line 418
            logTrace "descMap.data.size = ${descMap.data.size()}" // library marker rbn.common, line 419
        } // library marker rbn.common, line 420
        logDebug "Received Read Reporting Configuration Response (0x09) for cluster:${descMap.clusterId} attribute:${descMap.data[3] + descMap.data[2]}, data=${descMap.data} (Status: ${descMap.data[0] == '00' ? 'Success' : '<b>Failure</b>'}) min=${min} max=${max} delta=${delta}" // library marker rbn.common, line 421
    } // library marker rbn.common, line 422
    else { // library marker rbn.common, line 423
        logWarn "<b>Not Found (0x8b)</b> Read Reporting Configuration Response for cluster:${descMap.clusterId} attribute:${descMap.data[3] + descMap.data[2]}, data=${descMap.data} (Status: ${descMap.data[0] == '00' ? 'Success' : '<b>Failure</b>'})" // library marker rbn.common, line 424
    } // library marker rbn.common, line 425
} // library marker rbn.common, line 426
 // library marker rbn.common, line 427
private Boolean executeCustomHandler(String handlerName, Object handlerArgs) { // library marker rbn.common, line 428
    if (!this.respondsTo(handlerName)) { // library marker rbn.common, line 429
        logTrace "executeCustomHandler: function <b>${handlerName}</b> not found" // library marker rbn.common, line 430
        return false // library marker rbn.common, line 431
    } // library marker rbn.common, line 432
    // execute the customHandler function // library marker rbn.common, line 433
    Boolean result = false // library marker rbn.common, line 434
    try { // library marker rbn.common, line 435
        result = "$handlerName"(handlerArgs) // library marker rbn.common, line 436
    } // library marker rbn.common, line 437
    catch (e) { // library marker rbn.common, line 438
        logWarn "executeCustomHandler: Exception '${e}'caught while processing <b>$handlerName</b>(<b>$handlerArgs</b>) (val=${fncmd}))" // library marker rbn.common, line 439
        return false // library marker rbn.common, line 440
    } // library marker rbn.common, line 441
    //logDebug "customSetFunction result is ${fncmd}" // library marker rbn.common, line 442
    return result // library marker rbn.common, line 443
} // library marker rbn.common, line 444
 // library marker rbn.common, line 445
// Zigbee Default Command Response Parsing // library marker rbn.common, line 446
private void parseDefaultCommandResponse(final Map descMap) { // library marker rbn.common, line 447
    final List<String> data = descMap.data as List<String> // library marker rbn.common, line 448
    final String commandId = data[0] // library marker rbn.common, line 449
    final int statusCode = hexStrToUnsignedInt(data[1]) // library marker rbn.common, line 450
    final String status = ZigbeeStatusEnum[statusCode] ?: "0x${data[1]}" // library marker rbn.common, line 451
    if (statusCode > 0x00) { // library marker rbn.common, line 452
        logWarn "zigbee ${clusterLookup(descMap.clusterInt)} command 0x${commandId} error: ${status}" // library marker rbn.common, line 453
    } else { // library marker rbn.common, line 454
        logDebug "zigbee ${clusterLookup(descMap.clusterInt)} command 0x${commandId} response: ${status}" // library marker rbn.common, line 455
        // ZigUSB has its own interpretation of the Zigbee standards ... :( // library marker rbn.common, line 456
        if (this.respondsTo('customParseDefaultCommandResponse')) { // library marker rbn.common, line 457
            customParseDefaultCommandResponse(descMap) // library marker rbn.common, line 458
        } // library marker rbn.common, line 459
    } // library marker rbn.common, line 460
} // library marker rbn.common, line 461
 // library marker rbn.common, line 462
// Zigbee Attribute IDs // library marker rbn.common, line 463
@Field static final int ATTRIBUTE_READING_INFO_SET = 0x0000 // library marker rbn.common, line 464
@Field static final int FIRMWARE_VERSION_ID = 0x4000 // library marker rbn.common, line 465
@Field static final int PING_ATTR_ID = 0x01 // library marker rbn.common, line 466
 // library marker rbn.common, line 467
@Field static final Map<Integer, String> ZigbeeStatusEnum = [ // library marker rbn.common, line 468
    0x00: 'Success', 0x01: 'Failure', 0x02: 'Not Authorized', 0x80: 'Malformed Command', 0x81: 'Unsupported COMMAND', 0x85: 'Invalid Field', 0x86: 'Unsupported Attribute', 0x87: 'Invalid Value', 0x88: 'Read Only', // library marker rbn.common, line 469
    0x89: 'Insufficient Space', 0x8A: 'Duplicate Exists', 0x8B: 'Not Found', 0x8C: 'Unreportable Attribute', 0x8D: 'Invalid Data Type', 0x8E: 'Invalid Selector', 0x94: 'Time out', 0x9A: 'Notification Pending', 0xC3: 'Unsupported Cluster' // library marker rbn.common, line 470
] // library marker rbn.common, line 471
 // library marker rbn.common, line 472
@Field static final Map<Integer, String> ZigbeeGeneralCommandEnum = [ // library marker rbn.common, line 473
    0x00: 'Read Attributes', 0x01: 'Read Attributes Response', 0x02: 'Write Attributes', 0x03: 'Write Attributes Undivided', 0x04: 'Write Attributes Response', 0x05: 'Write Attributes No Response', 0x06: 'Configure Reporting', // library marker rbn.common, line 474
    0x07: 'Configure Reporting Response', 0x08: 'Read Reporting Configuration', 0x09: 'Read Reporting Configuration Response', 0x0A: 'Report Attributes', 0x0B: 'Default Response', 0x0C: 'Discover Attributes', 0x0D: 'Discover Attributes Response', // library marker rbn.common, line 475
    0x0E: 'Read Attributes Structured', 0x0F: 'Write Attributes Structured', 0x10: 'Write Attributes Structured Response', 0x11: 'Discover Commands Received', 0x12: 'Discover Commands Received Response', 0x13: 'Discover Commands Generated', // library marker rbn.common, line 476
    0x14: 'Discover Commands Generated Response', 0x15: 'Discover Attributes Extended', 0x16: 'Discover Attributes Extended Response' // library marker rbn.common, line 477
] // library marker rbn.common, line 478
 // library marker rbn.common, line 479
@Field static final int ROLLING_AVERAGE_N = 10 // library marker rbn.common, line 480
private BigDecimal approxRollingAverage(BigDecimal avgPar, BigDecimal newSample) { // library marker rbn.common, line 481
    BigDecimal avg = avgPar // library marker rbn.common, line 482
    if (avg == null || avg == 0) { avg = newSample } // library marker rbn.common, line 483
    avg -= avg / ROLLING_AVERAGE_N // library marker rbn.common, line 484
    avg += newSample / ROLLING_AVERAGE_N // library marker rbn.common, line 485
    return avg // library marker rbn.common, line 486
} // library marker rbn.common, line 487
 // library marker rbn.common, line 488
private void handlePingResponse() { // library marker rbn.common, line 489
    Long now = new Date().getTime() // library marker rbn.common, line 490
    if (state.lastRx == null) { state.lastRx = [:] } // library marker rbn.common, line 491
    state.lastRx['checkInTime'] = now // library marker rbn.common, line 492
 // library marker rbn.common, line 493
    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: '0').toInteger() // library marker rbn.common, line 494
    if (timeRunning > 0 && timeRunning < MAX_PING_MILISECONDS) { // library marker rbn.common, line 495
        state.stats['pingsOK'] = (state.stats['pingsOK'] ?: 0) + 1 // library marker rbn.common, line 496
        if (timeRunning < safeToInt((state.stats['pingsMin'] ?: '9999'))) { state.stats['pingsMin'] = timeRunning } // library marker rbn.common, line 497
        if (timeRunning > safeToInt((state.stats['pingsMax'] ?: '0')))   { state.stats['pingsMax'] = timeRunning } // library marker rbn.common, line 498
        state.stats['pingsAvg'] = approxRollingAverage(safeToDouble(state.stats['pingsAvg']), safeToDouble(timeRunning)) as int // library marker rbn.common, line 499
        sendRttEvent() // library marker rbn.common, line 500
    } // library marker rbn.common, line 501
    else { // library marker rbn.common, line 502
        logWarn "unexpected ping timeRunning=${timeRunning} " // library marker rbn.common, line 503
    } // library marker rbn.common, line 504
    state.states['isPing'] = false // library marker rbn.common, line 505
} // library marker rbn.common, line 506
 // library marker rbn.common, line 507
/* // library marker rbn.common, line 508
 * ----------------------------------------------------------------------------- // library marker rbn.common, line 509
 * Standard clusters reporting handlers // library marker rbn.common, line 510
 * ----------------------------------------------------------------------------- // library marker rbn.common, line 511
*/ // library marker rbn.common, line 512
@Field static final Map powerSourceOpts =  [ defaultValue: 0, options: [0: 'unknown', 1: 'mains', 2: 'mains', 3: 'battery', 4: 'dc', 5: 'emergency mains', 6: 'emergency mains']] // library marker rbn.common, line 513
 // library marker rbn.common, line 514
// Zigbee Basic Cluster Parsing  0x0000 - called from the main parse method // library marker rbn.common, line 515
private void standardParseBasicCluster(final Map descMap) { // library marker rbn.common, line 516
    Long now = new Date().getTime() // library marker rbn.common, line 517
    if (state.lastRx == null) { state.lastRx = [:] } // library marker rbn.common, line 518
    state.lastRx['checkInTime'] = now // library marker rbn.common, line 519
    boolean isPing = state.states?.isPing ?: false // library marker rbn.common, line 520
    switch (descMap.attrInt as Integer) { // library marker rbn.common, line 521
        case 0x0000: // library marker rbn.common, line 522
            logDebug "Basic cluster: ZCLVersion = ${descMap?.value}" // library marker rbn.common, line 523
            break // library marker rbn.common, line 524
        case PING_ATTR_ID: // 0x01 - Using 0x01 read as a simple ping/pong mechanism // library marker rbn.common, line 525
            if (isPing) { // library marker rbn.common, line 526
                handlePingResponse() // library marker rbn.common, line 527
            } // library marker rbn.common, line 528
            else { // library marker rbn.common, line 529
                logTrace "Tuya check-in message (attribute ${descMap.attrId} reported: ${descMap.value})" // library marker rbn.common, line 530
            } // library marker rbn.common, line 531
            break // library marker rbn.common, line 532
        case 0x0004: // library marker rbn.common, line 533
            logDebug "received device manufacturer ${descMap?.value}" // library marker rbn.common, line 534
            // received device manufacturer IKEA of Sweden // library marker rbn.common, line 535
            String manufacturer = device.getDataValue('manufacturer') // library marker rbn.common, line 536
            if ((manufacturer == null || manufacturer == 'unknown') && (descMap?.value != null)) { // library marker rbn.common, line 537
                logWarn "updating device manufacturer from ${manufacturer} to ${descMap?.value}" // library marker rbn.common, line 538
                device.updateDataValue('manufacturer', descMap?.value) // library marker rbn.common, line 539
            } // library marker rbn.common, line 540
            break // library marker rbn.common, line 541
        case 0x0005: // library marker rbn.common, line 542
            if (isPing) { // library marker rbn.common, line 543
                handlePingResponse() // library marker rbn.common, line 544
            } // library marker rbn.common, line 545
            else { // library marker rbn.common, line 546
                logDebug "received device model ${descMap?.value}" // library marker rbn.common, line 547
                // received device model Remote Control N2 // library marker rbn.common, line 548
                String model = device.getDataValue('model') // library marker rbn.common, line 549
                if ((model == null || model == 'unknown') && (descMap?.value != null)) { // library marker rbn.common, line 550
                    logWarn "updating device model from ${model} to ${descMap?.value}" // library marker rbn.common, line 551
                    device.updateDataValue('model', descMap?.value) // library marker rbn.common, line 552
                } // library marker rbn.common, line 553
            } // library marker rbn.common, line 554
            break // library marker rbn.common, line 555
        case 0x0007: // library marker rbn.common, line 556
            String powerSourceReported = powerSourceOpts.options[descMap?.value as int] // library marker rbn.common, line 557
            logDebug "received Power source <b>${powerSourceReported}</b> (${descMap?.value})" // library marker rbn.common, line 558
            String currentPowerSource = device.getDataValue('powerSource') // library marker rbn.common, line 559
            if (currentPowerSource == null || currentPowerSource == 'unknown') { // library marker rbn.common, line 560
                logInfo "updating device powerSource from ${currentPowerSource} to ${powerSourceReported}" // library marker rbn.common, line 561
                sendEvent(name: 'powerSource', value: powerSourceReported, type: 'physical') // library marker rbn.common, line 562
            } // library marker rbn.common, line 563
            break // library marker rbn.common, line 564
        case 0xFFDF: // library marker rbn.common, line 565
            logDebug "Tuya check-in (Cluster Revision=${descMap?.value})" // library marker rbn.common, line 566
            break // library marker rbn.common, line 567
        case 0xFFE2: // library marker rbn.common, line 568
            logDebug "Tuya check-in (AppVersion=${descMap?.value})" // library marker rbn.common, line 569
            break // library marker rbn.common, line 570
        case [0xFFE0, 0xFFE1, 0xFFE3, 0xFFE4] : // library marker rbn.common, line 571
            logTrace "Tuya attribute ${descMap?.attrId} value=${descMap?.value}" // library marker rbn.common, line 572
            break // library marker rbn.common, line 573
        case 0xFFFE: // library marker rbn.common, line 574
            logTrace "Tuya attributeReportingStatus (attribute FFFE) value=${descMap?.value}" // library marker rbn.common, line 575
            break // library marker rbn.common, line 576
        case FIRMWARE_VERSION_ID:    // 0x4000 // library marker rbn.common, line 577
            final String version = descMap.value ?: 'unknown' // library marker rbn.common, line 578
            logInfo "device firmware version is ${version}" // library marker rbn.common, line 579
            updateDataValue('softwareBuild', version) // library marker rbn.common, line 580
            break // library marker rbn.common, line 581
        default: // library marker rbn.common, line 582
            logDebug "zigbee received unknown Basic cluster attribute 0x${descMap.attrId} (value ${descMap.value})" // library marker rbn.common, line 583
            break // library marker rbn.common, line 584
    } // library marker rbn.common, line 585
} // library marker rbn.common, line 586
 // library marker rbn.common, line 587
private void standardParsePollControlCluster(final Map descMap) { // library marker rbn.common, line 588
    switch (descMap.attrInt as Integer) { // library marker rbn.common, line 589
        case 0x0000: logDebug "PollControl cluster: CheckInInterval = ${descMap?.value}" ; break // library marker rbn.common, line 590
        case 0x0001: logDebug "PollControl cluster: LongPollInterval = ${descMap?.value}" ; break // library marker rbn.common, line 591
        case 0x0002: logDebug "PollControl cluster: ShortPollInterval = ${descMap?.value}" ; break // library marker rbn.common, line 592
        case 0x0003: logDebug "PollControl cluster: FastPollTimeout = ${descMap?.value}" ; break // library marker rbn.common, line 593
        case 0x0004: logDebug "PollControl cluster: CheckInIntervalMin = ${descMap?.value}" ; break // library marker rbn.common, line 594
        case 0x0005: logDebug "PollControl cluster: LongPollIntervalMin = ${descMap?.value}" ; break // library marker rbn.common, line 595
        case 0x0006: logDebug "PollControl cluster: FastPollTimeoutMax = ${descMap?.value}" ; break // library marker rbn.common, line 596
        default: logDebug "zigbee received unknown PollControl cluster attribute 0x${descMap.attrId} (value ${descMap.value})" ; break // library marker rbn.common, line 597
    } // library marker rbn.common, line 598
} // library marker rbn.common, line 599
 // library marker rbn.common, line 600
public void clearIsDigital()        { state.states['isDigital'] = false } // library marker rbn.common, line 601
void switchDebouncingClear() { state.states['debounce']  = false } // library marker rbn.common, line 602
void isRefreshRequestClear() { state.states['isRefresh'] = false } // library marker rbn.common, line 603
 // library marker rbn.common, line 604
Map myParseDescriptionAsMap(String description) { // library marker rbn.common, line 605
    Map descMap = [:] // library marker rbn.common, line 606
    try { // library marker rbn.common, line 607
        descMap = zigbee.parseDescriptionAsMap(description) // library marker rbn.common, line 608
    } // library marker rbn.common, line 609
    catch (e1) { // library marker rbn.common, line 610
        logWarn "exception ${e1} caught while parseDescriptionAsMap <b>myParseDescriptionAsMap</b> description:  ${description}" // library marker rbn.common, line 611
        // try alternative custom parsing // library marker rbn.common, line 612
        descMap = [:] // library marker rbn.common, line 613
        try { // library marker rbn.common, line 614
            descMap += description.replaceAll('\\[|\\]', '').split(',').collectEntries { entry -> // library marker rbn.common, line 615
                List<String> pair = entry.split(':') // library marker rbn.common, line 616
                [(pair.first().trim()): pair.last().trim()] // library marker rbn.common, line 617
            } // library marker rbn.common, line 618
        } // library marker rbn.common, line 619
        catch (e2) { // library marker rbn.common, line 620
            logWarn "exception ${e2} caught while parsing using an alternative method <b>myParseDescriptionAsMap</b> description:  ${description}" // library marker rbn.common, line 621
            return [:] // library marker rbn.common, line 622
        } // library marker rbn.common, line 623
        logDebug "alternative method parsing success: descMap=${descMap}" // library marker rbn.common, line 624
    } // library marker rbn.common, line 625
    return descMap // library marker rbn.common, line 626
} // library marker rbn.common, line 627
 // library marker rbn.common, line 628
public String intTo16bitUnsignedHex(int value) { // library marker rbn.common, line 629
    String hexStr = zigbee.convertToHexString(value.toInteger(), 4) // library marker rbn.common, line 630
    return new String(hexStr.substring(2, 4) + hexStr.substring(0, 2)) // library marker rbn.common, line 631
} // library marker rbn.common, line 632
 // library marker rbn.common, line 633
public String intTo8bitUnsignedHex(int value) { // library marker rbn.common, line 634
    return zigbee.convertToHexString(value.toInteger(), 2) // library marker rbn.common, line 635
} // library marker rbn.common, line 636
 // library marker rbn.common, line 637
public void aqaraBlackMagic() { // library marker rbn.common, line 638
    List<String> cmds = [] // library marker rbn.common, line 639
    if (this.respondsTo('customAqaraBlackMagic')) { // library marker rbn.common, line 640
        cmds = customAqaraBlackMagic() // library marker rbn.common, line 641
    } // library marker rbn.common, line 642
    if (cmds != null && !cmds.isEmpty()) { // library marker rbn.common, line 643
        logDebug 'sending aqaraBlackMagic()' // library marker rbn.common, line 644
        sendZigbeeCommands(cmds) // library marker rbn.common, line 645
        return // library marker rbn.common, line 646
    } // library marker rbn.common, line 647
    logDebug 'aqaraBlackMagic() was SKIPPED' // library marker rbn.common, line 648
} // library marker rbn.common, line 649
 // library marker rbn.common, line 650
// Invoked from configure() // library marker rbn.common, line 651
public List<String> initializeDevice() { // library marker rbn.common, line 652
    List<String> cmds = [] // library marker rbn.common, line 653
    logInfo 'initializeDevice...' // library marker rbn.common, line 654
    if (this.respondsTo('customInitializeDevice')) { // library marker rbn.common, line 655
        List<String> customCmds = customInitializeDevice() // library marker rbn.common, line 656
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // library marker rbn.common, line 657
    } // library marker rbn.common, line 658
    else { logDebug 'no customInitializeDevice method defined' } // library marker rbn.common, line 659
    logDebug "initializeDevice(): cmds=${cmds}" // library marker rbn.common, line 660
    return cmds // library marker rbn.common, line 661
} // library marker rbn.common, line 662
 // library marker rbn.common, line 663
// Invoked from configure() // library marker rbn.common, line 664
public List<String> configureDevice() { // library marker rbn.common, line 665
    List<String> cmds = [] // library marker rbn.common, line 666
    logInfo 'configureDevice...' // library marker rbn.common, line 667
    if (this.respondsTo('customConfigureDevice')) { // library marker rbn.common, line 668
        List<String> customCmds = customConfigureDevice() // library marker rbn.common, line 669
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // library marker rbn.common, line 670
    } // library marker rbn.common, line 671
    else { logDebug 'no customConfigureDevice method defined' } // library marker rbn.common, line 672
    // sendZigbeeCommands(cmds) changed 03/04/2024 // library marker rbn.common, line 673
    logDebug "configureDevice(): cmds=${cmds}" // library marker rbn.common, line 674
    return cmds // library marker rbn.common, line 675
} // library marker rbn.common, line 676
 // library marker rbn.common, line 677
/* // library marker rbn.common, line 678
 * ----------------------------------------------------------------------------- // library marker rbn.common, line 679
 * Hubitat default handlers methods // library marker rbn.common, line 680
 * ----------------------------------------------------------------------------- // library marker rbn.common, line 681
*/ // library marker rbn.common, line 682
 // library marker rbn.common, line 683
List<String> customHandlers(final List customHandlersList) { // library marker rbn.common, line 684
    List<String> cmds = [] // library marker rbn.common, line 685
    if (customHandlersList != null && !customHandlersList.isEmpty()) { // library marker rbn.common, line 686
        customHandlersList.each { handler -> // library marker rbn.common, line 687
            if (this.respondsTo(handler)) { // library marker rbn.common, line 688
                List<String> customCmds = this."${handler}"() // library marker rbn.common, line 689
                if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } // library marker rbn.common, line 690
            } // library marker rbn.common, line 691
        } // library marker rbn.common, line 692
    } // library marker rbn.common, line 693
    return cmds // library marker rbn.common, line 694
} // library marker rbn.common, line 695
 // library marker rbn.common, line 696
public void refresh() { // library marker rbn.common, line 697
    logDebug "refresh()... DEVICE_TYPE is ${DEVICE_TYPE} model=${device.getDataValue('model')} manufacturer=${device.getDataValue('manufacturer')}" // library marker rbn.common, line 698
    checkDriverVersion(state) // library marker rbn.common, line 699
    List<String> cmds = [], customCmds = [] // library marker rbn.common, line 700
    if (this.respondsTo('customRefresh')) {     // if there is a customRefresh() method defined in the main driver, call it // library marker rbn.common, line 701
        customCmds = customRefresh() // library marker rbn.common, line 702
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } else { logDebug 'no customRefresh method defined' } // library marker rbn.common, line 703
    } // library marker rbn.common, line 704
    else {  // call all known libraryRefresh methods // library marker rbn.common, line 705
        customCmds = customHandlers(['onOffRefresh', 'groupsRefresh', 'batteryRefresh', 'levelRefresh', 'temperatureRefresh', 'humidityRefresh', 'illuminanceRefresh']) // library marker rbn.common, line 706
        if (customCmds != null && !customCmds.isEmpty()) { cmds +=  customCmds } else { logDebug 'no libraries refresh() defined' } // library marker rbn.common, line 707
    } // library marker rbn.common, line 708
    if (cmds != null && !cmds.isEmpty()) { // library marker rbn.common, line 709
        logDebug "refresh() cmds=${cmds}" // library marker rbn.common, line 710
        setRefreshRequest()    // 3 seconds // library marker rbn.common, line 711
        sendZigbeeCommands(cmds) // library marker rbn.common, line 712
    } // library marker rbn.common, line 713
    else { // library marker rbn.common, line 714
        logDebug "no refresh() commands defined for device type ${DEVICE_TYPE}" // library marker rbn.common, line 715
    } // library marker rbn.common, line 716
} // library marker rbn.common, line 717
 // library marker rbn.common, line 718
public void setRefreshRequest()   { if (state.states == null) { state.states = [:] } ; state.states['isRefresh'] = true; runInMillis(REFRESH_TIMER, 'clearRefreshRequest', [overwrite: true]) } // library marker rbn.common, line 719
public void clearRefreshRequest() { if (state.states == null) { state.states = [:] } ; state.states['isRefresh'] = false } // library marker rbn.common, line 720
public void clearInfoEvent()      { sendInfoEvent('clear') } // library marker rbn.common, line 721
 // library marker rbn.common, line 722
public void sendInfoEvent(String info=null) { // library marker rbn.common, line 723
    if (info == null || info == 'clear') { // library marker rbn.common, line 724
        logDebug 'clearing the Status event' // library marker rbn.common, line 725
        sendEvent(name: '_status_', value: 'clear', type: 'digital') // library marker rbn.common, line 726
    } // library marker rbn.common, line 727
    else { // library marker rbn.common, line 728
        logInfo "${info}" // library marker rbn.common, line 729
        sendEvent(name: '_status_', value: info, type: 'digital') // library marker rbn.common, line 730
        runIn(INFO_AUTO_CLEAR_PERIOD, 'clearInfoEvent')            // automatically clear the Info attribute after 1 minute // library marker rbn.common, line 731
    } // library marker rbn.common, line 732
} // library marker rbn.common, line 733
 // library marker rbn.common, line 734
public void ping() { // library marker rbn.common, line 735
    if (state.lastTx == null ) { state.lastTx = [:] } ; state.lastTx['pingTime'] = new Date().getTime() // library marker rbn.common, line 736
    if (state.states == null ) { state.states = [:] } ; state.states['isPing'] = true // library marker rbn.common, line 737
    scheduleCommandTimeoutCheck() // library marker rbn.common, line 738
    int  pingAttr = (device.getDataValue('manufacturer') == 'SONOFF') ? 0x05 : PING_ATTR_ID // library marker rbn.common, line 739
    if (isVirtual()) { runInMillis(10, 'virtualPong') } // library marker rbn.common, line 740
    else if (device.getDataValue('manufacturer') == 'Aqara') { // library marker rbn.common, line 741
        logDebug 'Aqara device ping...' // library marker rbn.common, line 742
        sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, pingAttr, [destEndpoint: 0x01], 0) ) // library marker rbn.common, line 743
    } // library marker rbn.common, line 744
    else { sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, pingAttr, [:], 0) ) } // library marker rbn.common, line 745
    logDebug 'ping...' // library marker rbn.common, line 746
} // library marker rbn.common, line 747
 // library marker rbn.common, line 748
private void virtualPong() { // library marker rbn.common, line 749
    logDebug 'virtualPing: pong!' // library marker rbn.common, line 750
    Long now = new Date().getTime() // library marker rbn.common, line 751
    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: '0').toInteger() // library marker rbn.common, line 752
    if (timeRunning > 0 && timeRunning < MAX_PING_MILISECONDS) { // library marker rbn.common, line 753
        state.stats['pingsOK'] = (state.stats['pingsOK'] ?: 0) + 1 // library marker rbn.common, line 754
        if (timeRunning < safeToInt((state.stats['pingsMin'] ?: '9999'))) { state.stats['pingsMin'] = timeRunning } // library marker rbn.common, line 755
        if (timeRunning > safeToInt((state.stats['pingsMax'] ?: '0')))   { state.stats['pingsMax'] = timeRunning } // library marker rbn.common, line 756
        state.stats['pingsAvg'] = approxRollingAverage(safeToDouble(state.stats['pingsAvg']), safeToDouble(timeRunning)) as int // library marker rbn.common, line 757
        sendRttEvent() // library marker rbn.common, line 758
    } // library marker rbn.common, line 759
    else { // library marker rbn.common, line 760
        logWarn "unexpected ping timeRunning=${timeRunning} " // library marker rbn.common, line 761
    } // library marker rbn.common, line 762
    state.states['isPing'] = false // library marker rbn.common, line 763
    unscheduleCommandTimeoutCheck(state) // library marker rbn.common, line 764
} // library marker rbn.common, line 765
 // library marker rbn.common, line 766
public void sendRttEvent( String value=null) { // library marker rbn.common, line 767
    Long now = new Date().getTime() // library marker rbn.common, line 768
    if (state.lastTx == null ) { state.lastTx = [:] } // library marker rbn.common, line 769
    int timeRunning = now.toInteger() - (state.lastTx['pingTime'] ?: now).toInteger() // library marker rbn.common, line 770
    String descriptionText = "Round-trip time is ${timeRunning} ms (min=${state.stats['pingsMin']} max=${state.stats['pingsMax']} average=${state.stats['pingsAvg']})" // library marker rbn.common, line 771
    if (value == null) { // library marker rbn.common, line 772
        logInfo "${descriptionText}" // library marker rbn.common, line 773
        sendEvent(name: 'rtt', value: timeRunning, descriptionText: descriptionText, unit: 'ms', type: 'physical') // library marker rbn.common, line 774
    } // library marker rbn.common, line 775
    else { // library marker rbn.common, line 776
        descriptionText = "Round-trip time : ${value}" // library marker rbn.common, line 777
        logInfo "${descriptionText}" // library marker rbn.common, line 778
        sendEvent(name: 'rtt', value: value, descriptionText: descriptionText, type: 'physical') // library marker rbn.common, line 779
    } // library marker rbn.common, line 780
} // library marker rbn.common, line 781
 // library marker rbn.common, line 782
private String clusterLookup(final Object cluster) { // library marker rbn.common, line 783
    if (cluster != null) { // library marker rbn.common, line 784
        return zigbee.clusterLookup(cluster.toInteger()) ?: "private cluster 0x${intToHexStr(cluster.toInteger())}" // library marker rbn.common, line 785
    } // library marker rbn.common, line 786
    logWarn 'cluster is NULL!' // library marker rbn.common, line 787
    return 'NULL' // library marker rbn.common, line 788
} // library marker rbn.common, line 789
 // library marker rbn.common, line 790
private void scheduleCommandTimeoutCheck(int delay = COMMAND_TIMEOUT) { // library marker rbn.common, line 791
    if (state.states == null) { state.states = [:] } // library marker rbn.common, line 792
    state.states['isTimeoutCheck'] = true // library marker rbn.common, line 793
    runIn(delay, 'deviceCommandTimeout') // library marker rbn.common, line 794
} // library marker rbn.common, line 795
 // library marker rbn.common, line 796
// unschedule() is a very time consuming operation : ~ 5 milliseconds per call ! // library marker rbn.common, line 797
void unscheduleCommandTimeoutCheck(final Map state) {   // can not be static :( // library marker rbn.common, line 798
    if (state.states == null) { state.states = [:] } // library marker rbn.common, line 799
    if (state.states['isTimeoutCheck'] == true) { // library marker rbn.common, line 800
        state.states['isTimeoutCheck'] = false // library marker rbn.common, line 801
        unschedule('deviceCommandTimeout') // library marker rbn.common, line 802
    } // library marker rbn.common, line 803
} // library marker rbn.common, line 804
 // library marker rbn.common, line 805
void deviceCommandTimeout() { // library marker rbn.common, line 806
    logWarn 'no response received (sleepy device or offline?)' // library marker rbn.common, line 807
    sendRttEvent('timeout') // library marker rbn.common, line 808
    state.stats['pingsFail'] = (state.stats['pingsFail'] ?: 0) + 1 // library marker rbn.common, line 809
    if (state.health?.isHealthCheck == true) { // library marker rbn.common, line 810
        logWarn 'device health check failed!' // library marker rbn.common, line 811
        state.health?.checkCtr3 = (state.health?.checkCtr3 ?: 0 ) + 1 // library marker rbn.common, line 812
        if (state.health?.checkCtr3 >= PRESENCE_COUNT_THRESHOLD) { // library marker rbn.common, line 813
            if ((device.currentValue('healthStatus') ?: 'unknown') != 'offline' ) { // library marker rbn.common, line 814
                sendHealthStatusEvent('offline') // library marker rbn.common, line 815
            } // library marker rbn.common, line 816
        } // library marker rbn.common, line 817
        state.health['isHealthCheck'] = false // library marker rbn.common, line 818
    } // library marker rbn.common, line 819
} // library marker rbn.common, line 820
 // library marker rbn.common, line 821
private void scheduleDeviceHealthCheck(final int intervalMins, final int healthMethod) { // library marker rbn.common, line 822
    if (healthMethod == 1 || healthMethod == 2)  { // library marker rbn.common, line 823
        String cron = getCron( intervalMins * 60 ) // library marker rbn.common, line 824
        schedule(cron, 'deviceHealthCheck') // library marker rbn.common, line 825
        logDebug "deviceHealthCheck is scheduled every ${intervalMins} minutes" // library marker rbn.common, line 826
    } // library marker rbn.common, line 827
    else { // library marker rbn.common, line 828
        logWarn 'deviceHealthCheck is not scheduled!' // library marker rbn.common, line 829
        unschedule('deviceHealthCheck') // library marker rbn.common, line 830
    } // library marker rbn.common, line 831
} // library marker rbn.common, line 832
 // library marker rbn.common, line 833
private void unScheduleDeviceHealthCheck() { // library marker rbn.common, line 834
    unschedule('deviceHealthCheck') // library marker rbn.common, line 835
    device.deleteCurrentState('healthStatus') // library marker rbn.common, line 836
    logWarn 'device health check is disabled!' // library marker rbn.common, line 837
} // library marker rbn.common, line 838
 // library marker rbn.common, line 839
// called when any event was received from the Zigbee device in the parse() method. // library marker rbn.common, line 840
private void setHealthStatusOnline(Map state) { // library marker rbn.common, line 841
    if (state.health == null) { state.health = [:] } // library marker rbn.common, line 842
    state.health['checkCtr3']  = 0 // library marker rbn.common, line 843
    if (!((device.currentValue('healthStatus') ?: 'unknown') in ['online'])) { // library marker rbn.common, line 844
        sendHealthStatusEvent('online') // library marker rbn.common, line 845
        logInfo 'is now online!' // library marker rbn.common, line 846
    } // library marker rbn.common, line 847
} // library marker rbn.common, line 848
 // library marker rbn.common, line 849
private void deviceHealthCheck() { // library marker rbn.common, line 850
    checkDriverVersion(state) // library marker rbn.common, line 851
    if (state.health == null) { state.health = [:] } // library marker rbn.common, line 852
    int ctr = state.health['checkCtr3'] ?: 0 // library marker rbn.common, line 853
    if (ctr  >= PRESENCE_COUNT_THRESHOLD) { // library marker rbn.common, line 854
        if ((device.currentValue('healthStatus') ?: 'unknown') != 'offline' ) { // library marker rbn.common, line 855
            logWarn 'not present!' // library marker rbn.common, line 856
            sendHealthStatusEvent('offline') // library marker rbn.common, line 857
        } // library marker rbn.common, line 858
    } // library marker rbn.common, line 859
    else { // library marker rbn.common, line 860
        logDebug "deviceHealthCheck - online (notPresentCounter=${(ctr + 1)})" // library marker rbn.common, line 861
    } // library marker rbn.common, line 862
    state.health['checkCtr3'] = ctr + 1 // library marker rbn.common, line 863
    // added 03/06/2025 // library marker rbn.common, line 864
    if (settings?.healthCheckMethod as int == 2) { // library marker rbn.common, line 865
        state.health['isHealthCheck'] = true // library marker rbn.common, line 866
        ping()  // proactively ping the device... // library marker rbn.common, line 867
    } // library marker rbn.common, line 868
} // library marker rbn.common, line 869
 // library marker rbn.common, line 870
private void sendHealthStatusEvent(final String value) { // library marker rbn.common, line 871
    String descriptionText = "healthStatus changed to ${value}" // library marker rbn.common, line 872
    sendEvent(name: 'healthStatus', value: value, descriptionText: descriptionText, isStateChange: true, type: 'digital') // library marker rbn.common, line 873
    if (value == 'online') { // library marker rbn.common, line 874
        logInfo "${descriptionText}" // library marker rbn.common, line 875
    } // library marker rbn.common, line 876
    else { // library marker rbn.common, line 877
        if (settings?.txtEnable) { log.warn "${device.displayName} <b>${descriptionText}</b>" } // library marker rbn.common, line 878
    } // library marker rbn.common, line 879
} // library marker rbn.common, line 880
 // library marker rbn.common, line 881
 // Invoked by Hubitat when the driver configuration is updated // library marker rbn.common, line 882
void updated() { // library marker rbn.common, line 883
    logInfo 'updated()...' // library marker rbn.common, line 884
    checkDriverVersion(state) // library marker rbn.common, line 885
    logInfo"driver version ${driverVersionAndTimeStamp()}" // library marker rbn.common, line 886
    unschedule() // library marker rbn.common, line 887
 // library marker rbn.common, line 888
    if (settings.logEnable) { // library marker rbn.common, line 889
        logTrace(settings.toString()) // library marker rbn.common, line 890
        runIn(86400, 'logsOff') // library marker rbn.common, line 891
    } // library marker rbn.common, line 892
    if (settings.traceEnable) { // library marker rbn.common, line 893
        logTrace(settings.toString()) // library marker rbn.common, line 894
        runIn(1800, 'traceOff') // library marker rbn.common, line 895
    } // library marker rbn.common, line 896
 // library marker rbn.common, line 897
    final int healthMethod = (settings.healthCheckMethod as Integer) ?: 0 // library marker rbn.common, line 898
    if (healthMethod == 1 || healthMethod == 2) {                            //    [0: 'Disabled', 1: 'Activity check', 2: 'Periodic polling'] // library marker rbn.common, line 899
        // schedule the periodic timer // library marker rbn.common, line 900
        final int interval = (settings.healthCheckInterval as Integer) ?: 0 // library marker rbn.common, line 901
        if (interval > 0) { // library marker rbn.common, line 902
            //log.trace "healthMethod=${healthMethod} interval=${interval}" // library marker rbn.common, line 903
            log.info "scheduling health check every ${interval} minutes by ${HealthcheckMethodOpts.options[healthMethod]} method" // library marker rbn.common, line 904
            scheduleDeviceHealthCheck(interval, healthMethod) // library marker rbn.common, line 905
        } // library marker rbn.common, line 906
    } // library marker rbn.common, line 907
    else { // library marker rbn.common, line 908
        unScheduleDeviceHealthCheck()        // unschedule the periodic job, depending on the healthMethod // library marker rbn.common, line 909
        log.info 'Health Check is disabled!' // library marker rbn.common, line 910
    } // library marker rbn.common, line 911
    if (this.respondsTo('customUpdated')) { // library marker rbn.common, line 912
        customUpdated() // library marker rbn.common, line 913
    } // library marker rbn.common, line 914
 // library marker rbn.common, line 915
    sendInfoEvent('updated') // library marker rbn.common, line 916
} // library marker rbn.common, line 917
 // library marker rbn.common, line 918
private void logsOff() { // library marker rbn.common, line 919
    logInfo 'debug logging disabled...' // library marker rbn.common, line 920
    device.updateSetting('logEnable', [value: 'false', type: 'bool']) // library marker rbn.common, line 921
} // library marker rbn.common, line 922
private void traceOff() { // library marker rbn.common, line 923
    logInfo 'trace logging disabled...' // library marker rbn.common, line 924
    device.updateSetting('traceEnable', [value: 'false', type: 'bool']) // library marker rbn.common, line 925
} // library marker rbn.common, line 926
 // library marker rbn.common, line 927
// the administrative / diagnostic commands drop-down list. Deliberately NOT named 'configure' - overloading the Configuration capability command made the dispatch depend on whether the platform happens to supply an argument // library marker rbn.common, line 928
public void deviceUtilities(String command = null) { // library marker rbn.common, line 929
    logInfo "deviceUtilities(${command})..." // library marker rbn.common, line 930
    if (command == null || !(command in (ConfigureOpts.keySet() as List))) { // library marker rbn.common, line 931
        configureHelp(command)      // nothing was selected, or the value is not one of ours - show the help and do nothing else // library marker rbn.common, line 932
        return // library marker rbn.common, line 933
    } // library marker rbn.common, line 934
    // // library marker rbn.common, line 935
    String func // library marker rbn.common, line 936
    try { // library marker rbn.common, line 937
        func = ConfigureOpts[command]?.function // library marker rbn.common, line 938
        "$func"() // library marker rbn.common, line 939
    } // library marker rbn.common, line 940
    catch (e) { // library marker rbn.common, line 941
        logWarn "Exception ${e} caught while processing <b>$func</b>(<b>$value</b>)" // library marker rbn.common, line 942
        return // library marker rbn.common, line 943
    } // library marker rbn.common, line 944
    logInfo "executed '${func}'" // library marker rbn.common, line 945
} // library marker rbn.common, line 946
 // library marker rbn.common, line 947
/* groovylint-disable-next-line UnusedMethodParameter */ // library marker rbn.common, line 948
void configureHelp(final String val = null) { // library marker rbn.common, line 949
    logInfo "select one of the commands from the list: ${ConfigureOpts.keySet() as List}" // library marker rbn.common, line 950
    sendInfoEvent('Please select a command from the drop-down list')      // short _status_ event, auto-cleared after INFO_AUTO_CLEAR_PERIOD // library marker rbn.common, line 951
} // library marker rbn.common, line 952
 // library marker rbn.common, line 953
public void loadAllDefaults() { // library marker rbn.common, line 954
    logDebug 'loadAllDefaults() !!!' // library marker rbn.common, line 955
    deleteAllSettings() // library marker rbn.common, line 956
    deleteAllCurrentStates() // library marker rbn.common, line 957
    deleteAllScheduledJobs() // library marker rbn.common, line 958
    deleteAllStates() // library marker rbn.common, line 959
    deleteAllChildDevices() // library marker rbn.common, line 960
 // library marker rbn.common, line 961
    initialize() // library marker rbn.common, line 962
    configureNow()     // calls  also   configureDevice()   // bug fixed 04/03/2024 // library marker rbn.common, line 963
    updated() // library marker rbn.common, line 964
    sendInfoEvent('All Defaults Loaded! F5 to refresh') // library marker rbn.common, line 965
} // library marker rbn.common, line 966
 // library marker rbn.common, line 967
private void configureNow() { // library marker rbn.common, line 968
    configure() // library marker rbn.common, line 969
} // library marker rbn.common, line 970
 // library marker rbn.common, line 971
/** // library marker rbn.common, line 972
 * Send configuration parameters to the device // library marker rbn.common, line 973
 * Invoked when device is first installed and when the user updates the configuration  TODO // library marker rbn.common, line 974
 * @return sends zigbee commands // library marker rbn.common, line 975
 */ // library marker rbn.common, line 976
void configure() { // library marker rbn.common, line 977
    List<String> cmds = [] // library marker rbn.common, line 978
    if (state.stats == null) { state.stats = [:] } ; state.stats.cfgCtr = (state.stats.cfgCtr ?: 0) + 1 // library marker rbn.common, line 979
    logInfo "configure()... cfgCtr=${state.stats.cfgCtr}" // library marker rbn.common, line 980
    logDebug "configure(): settings: $settings" // library marker rbn.common, line 981
    aqaraBlackMagic()   // zigbee commands are sent here! // library marker rbn.common, line 982
    List<String> initCmds = initializeDevice() // library marker rbn.common, line 983
    if (initCmds != null && !initCmds.isEmpty()) { cmds += initCmds } // library marker rbn.common, line 984
    List<String> cfgCmds = configureDevice() // library marker rbn.common, line 985
    if (cfgCmds != null && !cfgCmds.isEmpty()) { cmds += cfgCmds } // library marker rbn.common, line 986
    if (cmds != null && !cmds.isEmpty()) { // library marker rbn.common, line 987
        sendZigbeeCommands(cmds) // library marker rbn.common, line 988
        logDebug "configure(): sent cmds = ${cmds}" // library marker rbn.common, line 989
        sendInfoEvent('sent device configuration') // library marker rbn.common, line 990
    } // library marker rbn.common, line 991
    else { // library marker rbn.common, line 992
        logDebug "configure(): no commands defined for device type ${DEVICE_TYPE}" // library marker rbn.common, line 993
    } // library marker rbn.common, line 994
} // library marker rbn.common, line 995
 // library marker rbn.common, line 996
 // Invoked when the device is installed with this driver automatically selected. // library marker rbn.common, line 997
void installed() { // library marker rbn.common, line 998
    if (state.stats == null) { state.stats = [:] } ; state.stats.instCtr = (state.stats.instCtr ?: 0) + 1 // library marker rbn.common, line 999
    logInfo "installed()... instCtr=${state.stats.instCtr}" // library marker rbn.common, line 1000
    // populate some default values for attributes // library marker rbn.common, line 1001
    sendEvent(name: 'healthStatus', value: 'unknown', descriptionText: 'device was installed', type: 'digital') // library marker rbn.common, line 1002
    sendEvent(name: 'powerSource',  value: 'unknown', descriptionText: 'device was installed', type: 'digital') // library marker rbn.common, line 1003
    sendInfoEvent('installed') // library marker rbn.common, line 1004
    runIn(3, 'updated') // library marker rbn.common, line 1005
    runIn(5, 'queryPowerSource') // library marker rbn.common, line 1006
} // library marker rbn.common, line 1007
 // library marker rbn.common, line 1008
private void queryPowerSource() { // library marker rbn.common, line 1009
    sendZigbeeCommands(zigbee.readAttribute(zigbee.BASIC_CLUSTER, 0x0007, [:], 0)) // library marker rbn.common, line 1010
} // library marker rbn.common, line 1011
 // library marker rbn.common, line 1012
 // Invoked from 'LoadAllDefaults' // library marker rbn.common, line 1013
private void initialize() { // library marker rbn.common, line 1014
    if (state.stats == null) { state.stats = [:] } ; state.stats.initCtr = (state.stats.initCtr ?: 0) + 1 // library marker rbn.common, line 1015
    logDebug "initialize()... initCtr=${state.stats.initCtr}" // library marker rbn.common, line 1016
    if (device.getDataValue('powerSource') == null) { // library marker rbn.common, line 1017
        logDebug "initializing device powerSource 'unknown'" // library marker rbn.common, line 1018
        sendEvent(name: 'powerSource', value: 'unknown', type: 'digital') // library marker rbn.common, line 1019
    } // library marker rbn.common, line 1020
    if (this.respondsTo('customInitialize')) { customInitialize() }  // library marker rbn.common, line 1021
    initializeVars(fullInit = true) // library marker rbn.common, line 1022
    updateAqaraVersion() // library marker rbn.common, line 1023
} // library marker rbn.common, line 1024
 // library marker rbn.common, line 1025
/* // library marker rbn.common, line 1026
 *----------------------------------------------------------------------------- // library marker rbn.common, line 1027
 * kkossev drivers commonly used functions // library marker rbn.common, line 1028
 *----------------------------------------------------------------------------- // library marker rbn.common, line 1029
*/ // library marker rbn.common, line 1030
 // library marker rbn.common, line 1031
static Integer safeToInt(Object val, Integer defaultVal=0) { // library marker rbn.common, line 1032
    return "${val}"?.isInteger() ? "${val}".toInteger() : defaultVal // library marker rbn.common, line 1033
} // library marker rbn.common, line 1034
 // library marker rbn.common, line 1035
static Double safeToDouble(Object val, Double defaultVal=0.0) { // library marker rbn.common, line 1036
    return "${val}"?.isDouble() ? "${val}".toDouble() : defaultVal // library marker rbn.common, line 1037
} // library marker rbn.common, line 1038
 // library marker rbn.common, line 1039
static BigDecimal safeToBigDecimal(Object val, BigDecimal defaultVal=0.0) { // library marker rbn.common, line 1040
    return "${val}"?.isBigDecimal() ? "${val}".toBigDecimal() : defaultVal // library marker rbn.common, line 1041
} // library marker rbn.common, line 1042
 // library marker rbn.common, line 1043
public void sendZigbeeCommands(List<String> cmd) { // library marker rbn.common, line 1044
    if (cmd == null || cmd.isEmpty()) { // library marker rbn.common, line 1045
        logWarn "sendZigbeeCommands: list is empty! cmd=${cmd}" // library marker rbn.common, line 1046
        return // library marker rbn.common, line 1047
    } // library marker rbn.common, line 1048
    hubitat.device.HubMultiAction allActions = new hubitat.device.HubMultiAction() // library marker rbn.common, line 1049
    cmd.each { // library marker rbn.common, line 1050
        if (it == null || it.isEmpty() || it == 'null') { // library marker rbn.common, line 1051
            logWarn "sendZigbeeCommands it: no commands to send! it=${it} (cmd=${cmd})" // library marker rbn.common, line 1052
            return // library marker rbn.common, line 1053
        } // library marker rbn.common, line 1054
        allActions.add(new hubitat.device.HubAction(it, hubitat.device.Protocol.ZIGBEE)) // library marker rbn.common, line 1055
        if (state.stats != null) { state.stats['txCtr'] = (state.stats['txCtr'] ?: 0) + 1 } else { state.stats = [:] } // library marker rbn.common, line 1056
    } // library marker rbn.common, line 1057
    if (state.lastTx != null) { state.lastTx['cmdTime'] = now() } else { state.lastTx = [:] } // library marker rbn.common, line 1058
    sendHubCommand(allActions) // library marker rbn.common, line 1059
    logDebug "sendZigbeeCommands: sent cmd=${cmd}" // library marker rbn.common, line 1060
} // library marker rbn.common, line 1061
 // library marker rbn.common, line 1062
private String driverVersionAndTimeStamp() { version() + ' ' + timeStamp() + ((_DEBUG) ? ' (debug version!) ' : ' ') + "(${device.getDataValue('model')} ${device.getDataValue('manufacturer')}) (${getModel()} ${location.hub.firmwareVersionString})" } // library marker rbn.common, line 1063
 // library marker rbn.common, line 1064
private String getDeviceInfo() { // library marker rbn.common, line 1065
    return "model=${device.getDataValue('model')} manufacturer=${device.getDataValue('manufacturer')} destinationEP=${state.destinationEP ?: UNKNOWN} <b>deviceProfile=${state.deviceProfile ?: UNKNOWN}</b>" // library marker rbn.common, line 1066
} // library marker rbn.common, line 1067
 // library marker rbn.common, line 1068
public String getDestinationEP() {    // [destEndpoint:safeToInt(getDestinationEP())] // library marker rbn.common, line 1069
    return state.destinationEP ?: device.endpointId ?: '01' // library marker rbn.common, line 1070
} // library marker rbn.common, line 1071
 // library marker rbn.common, line 1072
//@CompileStatic // library marker rbn.common, line 1073
public void checkDriverVersion(final Map stateCopy) { // library marker rbn.common, line 1074
    if (stateCopy.driverVersion == null || driverVersionAndTimeStamp() != stateCopy.driverVersion) { // library marker rbn.common, line 1075
        logDebug "checkDriverVersion: updating the settings from the current driver version ${stateCopy.driverVersion} to the new version ${driverVersionAndTimeStamp()}" // library marker rbn.common, line 1076
        sendInfoEvent("Updated to version ${driverVersionAndTimeStamp()} from version ${stateCopy.driverVersion ?: 'unknown'}") // library marker rbn.common, line 1077
        state.driverVersion = driverVersionAndTimeStamp() // library marker rbn.common, line 1078
        initializeVars(false) // library marker rbn.common, line 1079
        updateAqaraVersion() // library marker rbn.common, line 1080
        if (this.respondsTo('customcheckDriverVersion')) { customcheckDriverVersion(stateCopy) } // library marker rbn.common, line 1081
    } // library marker rbn.common, line 1082
    if (state.states == null) { state.states = [:] } ; if (state.lastRx == null) { state.lastRx = [:] } ; if (state.lastTx == null) { state.lastTx = [:] } ; if (state.stats  == null) { state.stats =  [:] } // library marker rbn.common, line 1083
} // library marker rbn.common, line 1084
 // library marker rbn.common, line 1085
// credits @thebearmay // library marker rbn.common, line 1086
String getModel() { // library marker rbn.common, line 1087
    try { // library marker rbn.common, line 1088
        /* groovylint-disable-next-line UnnecessaryGetter, UnusedVariable */ // library marker rbn.common, line 1089
        String model = getHubVersion() // requires >=2.2.8.141 // library marker rbn.common, line 1090
    } catch (ignore) { // library marker rbn.common, line 1091
        try { // library marker rbn.common, line 1092
            httpGet("http://${location.hub.localIP}:8080/api/hubitat.xml") { res -> // library marker rbn.common, line 1093
                model = res.data.device.modelName // library marker rbn.common, line 1094
                return model // library marker rbn.common, line 1095
            } // library marker rbn.common, line 1096
        } catch (ignore_again) { // library marker rbn.common, line 1097
            return '' // library marker rbn.common, line 1098
        } // library marker rbn.common, line 1099
    } // library marker rbn.common, line 1100
} // library marker rbn.common, line 1101
 // library marker rbn.common, line 1102
// credits @thebearmay // library marker rbn.common, line 1103
boolean isCompatible(Integer minLevel) { //check to see if the hub version meets the minimum requirement ( 7 or 8 ) // library marker rbn.common, line 1104
    String model = getModel()            // <modelName>Rev C-7</modelName> // library marker rbn.common, line 1105
    String[] tokens = model.split('-') // library marker rbn.common, line 1106
    String revision = tokens.last() // library marker rbn.common, line 1107
    return (Integer.parseInt(revision) >= minLevel) // library marker rbn.common, line 1108
} // library marker rbn.common, line 1109
 // library marker rbn.common, line 1110
void deleteAllStatesAndJobs() { // library marker rbn.common, line 1111
    state.clear()    // clear all states // library marker rbn.common, line 1112
    unschedule() // library marker rbn.common, line 1113
    device.deleteCurrentState('*') // library marker rbn.common, line 1114
    device.deleteCurrentState('') // library marker rbn.common, line 1115
 // library marker rbn.common, line 1116
    log.info "${device.displayName} jobs and states cleared. HE hub is ${getHubVersion()}, version is ${location.hub.firmwareVersionString}" // library marker rbn.common, line 1117
} // library marker rbn.common, line 1118
 // library marker rbn.common, line 1119
void resetStatistics() { // library marker rbn.common, line 1120
    runIn(1, 'resetStats') // library marker rbn.common, line 1121
    sendInfoEvent('Statistics are reset. Refresh the web page') // library marker rbn.common, line 1122
} // library marker rbn.common, line 1123
 // library marker rbn.common, line 1124
// called from initializeVars(true) and resetStatistics() // library marker rbn.common, line 1125
void resetStats() { // library marker rbn.common, line 1126
    logDebug 'resetStats...' // library marker rbn.common, line 1127
    state.stats = [:] ; state.states = [:] ; state.lastRx = [:] ; state.lastTx = [:] ; state.health = [:] // library marker rbn.common, line 1128
    if (this.respondsTo('groupsLibVersion')) { state.zigbeeGroups = [:] } // library marker rbn.common, line 1129
    state.stats.rxCtr = 0 ; state.stats.txCtr = 0 // library marker rbn.common, line 1130
    state.states['isDigital'] = false ; state.states['isRefresh'] = false ; state.states['isPing'] = false // library marker rbn.common, line 1131
    state.health['offlineCtr'] = 0 ; state.health['checkCtr3'] = 0 // library marker rbn.common, line 1132
    if (this.respondsTo('customResetStats')) { customResetStats() } // library marker rbn.common, line 1133
    logInfo 'statistics reset!' // library marker rbn.common, line 1134
} // library marker rbn.common, line 1135
 // library marker rbn.common, line 1136
void initializeVars( boolean fullInit = false ) { // library marker rbn.common, line 1137
    logDebug "InitializeVars()... fullInit = ${fullInit}" // library marker rbn.common, line 1138
    if (fullInit == true ) { // library marker rbn.common, line 1139
        state.clear() // library marker rbn.common, line 1140
        unschedule() // library marker rbn.common, line 1141
        resetStats() // library marker rbn.common, line 1142
        if (this.respondsTo('setDeviceNameAndProfile')) { setDeviceNameAndProfile() } // library marker rbn.common, line 1143
        //state.comment = 'Works with Tuya Zigbee Devices' // library marker rbn.common, line 1144
        logInfo 'all states and scheduled jobs cleared!' // library marker rbn.common, line 1145
        state.driverVersion = driverVersionAndTimeStamp() // library marker rbn.common, line 1146
        logInfo "DEVICE_TYPE = ${DEVICE_TYPE}" // library marker rbn.common, line 1147
        state.deviceType = DEVICE_TYPE // library marker rbn.common, line 1148
        sendInfoEvent('Initialized') // library marker rbn.common, line 1149
    } // library marker rbn.common, line 1150
 // library marker rbn.common, line 1151
    if (state.stats == null)  { state.stats  = [:] } // library marker rbn.common, line 1152
    if (state.states == null) { state.states = [:] } // library marker rbn.common, line 1153
    if (state.lastRx == null) { state.lastRx = [:] } // library marker rbn.common, line 1154
    if (state.lastTx == null) { state.lastTx = [:] } // library marker rbn.common, line 1155
    if (state.health == null) { state.health = [:] } // library marker rbn.common, line 1156
 // library marker rbn.common, line 1157
    if (fullInit || settings?.txtEnable == null) { device.updateSetting('txtEnable', true) } // library marker rbn.common, line 1158
    if (fullInit || settings?.logEnable == null) { device.updateSetting('logEnable', DEFAULT_DEBUG_LOGGING ?: false) } // library marker rbn.common, line 1159
    if (fullInit || settings?.traceEnable == null) { device.updateSetting('traceEnable', false) } // library marker rbn.common, line 1160
    if (fullInit || settings?.advancedOptions == null) { device.updateSetting('advancedOptions', [value:false, type:'bool']) } // library marker rbn.common, line 1161
    if (fullInit || settings?.healthCheckMethod == null) { device.updateSetting('healthCheckMethod', [value: HealthcheckMethodOpts.defaultValue.toString(), type: 'enum']) } // library marker rbn.common, line 1162
    if (fullInit || settings?.healthCheckInterval == null) { device.updateSetting('healthCheckInterval', [value: HealthcheckIntervalOpts.defaultValue.toString(), type: 'enum']) } // library marker rbn.common, line 1163
    if (fullInit || settings?.ignoreDuplicatedZigbeeMessages == null) { device.updateSetting('ignoreDuplicatedZigbeeMessages', false) } // library marker rbn.common, line 1164
    if (fullInit || settings?.voltageToPercent == null) { device.updateSetting('voltageToPercent', false) } // library marker rbn.common, line 1165
 // library marker rbn.common, line 1166
    if (device.currentValue('healthStatus') == null) { sendHealthStatusEvent('unknown') } // library marker rbn.common, line 1167
 // library marker rbn.common, line 1168
    // common libraries initialization // library marker rbn.common, line 1169
    executeCustomHandler('batteryInitializeVars', fullInit)     // added 07/06/2024 // library marker rbn.common, line 1170
    executeCustomHandler('motionInitializeVars', fullInit)      // added 07/06/2024 // library marker rbn.common, line 1171
    executeCustomHandler('groupsInitializeVars', fullInit) // library marker rbn.common, line 1172
    executeCustomHandler('illuminanceInitializeVars', fullInit) // library marker rbn.common, line 1173
    executeCustomHandler('onOfInitializeVars', fullInit) // library marker rbn.common, line 1174
    executeCustomHandler('energyInitializeVars', fullInit) // library marker rbn.common, line 1175
    // // library marker rbn.common, line 1176
    executeCustomHandler('deviceProfileInitializeVars', fullInit)   // must be before the other deviceProfile initialization handlers! // library marker rbn.common, line 1177
    executeCustomHandler('initEventsDeviceProfile', fullInit)   // added 07/06/2024 // library marker rbn.common, line 1178
    // // library marker rbn.common, line 1179
    // custom device driver specific initialization should be at the end // library marker rbn.common, line 1180
    executeCustomHandler('customInitializeVars', fullInit) // library marker rbn.common, line 1181
    executeCustomHandler('customCreateChildDevices', fullInit) // library marker rbn.common, line 1182
    executeCustomHandler('customInitEvents', fullInit) // library marker rbn.common, line 1183
 // library marker rbn.common, line 1184
    final String mm = device.getDataValue('model') // library marker rbn.common, line 1185
    if (mm != null) { logTrace " model = ${mm}" } // library marker rbn.common, line 1186
    else { logWarn ' Model not found, please re-pair the device!' } // library marker rbn.common, line 1187
    final String ep = device.getEndpointId() // library marker rbn.common, line 1188
    if ( ep  != null) { // library marker rbn.common, line 1189
        //state.destinationEP = ep // library marker rbn.common, line 1190
        logTrace " destinationEP = ${ep}" // library marker rbn.common, line 1191
    } // library marker rbn.common, line 1192
    else { // library marker rbn.common, line 1193
        logWarn ' Destination End Point not found, please re-pair the device!' // library marker rbn.common, line 1194
        //state.destinationEP = "01"    // fallback // library marker rbn.common, line 1195
    } // library marker rbn.common, line 1196
} // library marker rbn.common, line 1197
 // library marker rbn.common, line 1198
// not used!? // library marker rbn.common, line 1199
void setDestinationEP() { // library marker rbn.common, line 1200
    String ep = device.getEndpointId() // library marker rbn.common, line 1201
    if (ep != null && ep != 'F2') { state.destinationEP = ep ; logDebug "setDestinationEP() destinationEP = ${state.destinationEP}" } // library marker rbn.common, line 1202
    else { logWarn "setDestinationEP() Destination End Point not found or invalid(${ep}), activating the F2 bug patch!" ; state.destinationEP = '01' }   // fallback EP // library marker rbn.common, line 1203
} // library marker rbn.common, line 1204
 // library marker rbn.common, line 1205
void logDebug(final String msg) { if (settings?.logEnable)   { log.debug "${device.displayName} " + msg } } // library marker rbn.common, line 1206
void logInfo(final String msg)  { if (settings?.txtEnable)   { log.info  "${device.displayName} " + msg } } // library marker rbn.common, line 1207
void logWarn(final String msg)  { if (settings?.logEnable)   { log.warn  "${device.displayName} " + msg } } // library marker rbn.common, line 1208
void logTrace(final String msg) { if (settings?.traceEnable) { log.trace "${device.displayName} " + msg } } // library marker rbn.common, line 1209
void logError(final String msg) { if (settings?.txtEnable)   { log.error "${device.displayName} " + msg } } // library marker rbn.common, line 1210
 // library marker rbn.common, line 1211
// _DEBUG mode only // library marker rbn.common, line 1212
void getAllProperties() { // library marker rbn.common, line 1213
    log.trace 'Properties:' ; device.properties.each { it -> log.debug it } // library marker rbn.common, line 1214
    log.trace 'Settings:' ;  settings.each { it -> log.debug "${it.key} =  ${it.value}" }    // https://community.hubitat.com/t/how-do-i-get-the-datatype-for-an-app-setting/104228/6?u=kkossev // library marker rbn.common, line 1215
} // library marker rbn.common, line 1216
 // library marker rbn.common, line 1217
// delete all Preferences // library marker rbn.common, line 1218
void deleteAllSettings() { // library marker rbn.common, line 1219
    String preferencesDeleted = '' // library marker rbn.common, line 1220
    settings.each { it -> preferencesDeleted += "${it.key} (${it.value}), " ; device.removeSetting("${it.key}") } // library marker rbn.common, line 1221
    logDebug "Deleted settings: ${preferencesDeleted}" // library marker rbn.common, line 1222
    logInfo  'All settings (preferences) DELETED' // library marker rbn.common, line 1223
} // library marker rbn.common, line 1224
 // library marker rbn.common, line 1225
// delete all attributes // library marker rbn.common, line 1226
void deleteAllCurrentStates() { // library marker rbn.common, line 1227
    String attributesDeleted = '' // library marker rbn.common, line 1228
    device.properties.supportedAttributes.each { it -> attributesDeleted += "${it}, " ; device.deleteCurrentState("$it") } // library marker rbn.common, line 1229
    logDebug "Deleted attributes: ${attributesDeleted}" ; logInfo 'All current states (attributes) DELETED' // library marker rbn.common, line 1230
} // library marker rbn.common, line 1231
 // library marker rbn.common, line 1232
// delete all State Variables // library marker rbn.common, line 1233
void deleteAllStates() { // library marker rbn.common, line 1234
    String stateDeleted = '' // library marker rbn.common, line 1235
    state.each { it -> stateDeleted += "${it.key}, " } // library marker rbn.common, line 1236
    state.clear() // library marker rbn.common, line 1237
    logDebug "Deleted states: ${stateDeleted}" ; logInfo 'All States DELETED' // library marker rbn.common, line 1238
} // library marker rbn.common, line 1239
 // library marker rbn.common, line 1240
void deleteAllScheduledJobs() { // library marker rbn.common, line 1241
    unschedule() ; logInfo 'All scheduled jobs DELETED' // library marker rbn.common, line 1242
} // library marker rbn.common, line 1243
 // library marker rbn.common, line 1244
void deleteAllChildDevices() { // library marker rbn.common, line 1245
    getChildDevices().each { child -> log.info "${device.displayName} Deleting ${child.deviceNetworkId}" ; deleteChildDevice(child.deviceNetworkId) } // library marker rbn.common, line 1246
    sendInfoEvent 'All child devices DELETED' // library marker rbn.common, line 1247
} // library marker rbn.common, line 1248
 // library marker rbn.common, line 1249
void testParse(String par) { // library marker rbn.common, line 1250
    //read attr - raw: DF8D0104020A000029280A, dni: DF8D, endpoint: 01, cluster: 0402, size: 0A, attrId: 0000, encoding: 29, command: 0A, value: 280A // library marker rbn.common, line 1251
    log.trace '------------------------------------------------------' // library marker rbn.common, line 1252
    log.warn "testParse - <b>START</b> (${par})" // library marker rbn.common, line 1253
    parse(par) // library marker rbn.common, line 1254
    log.warn "testParse -   <b>END</b> (${par})" // library marker rbn.common, line 1255
    log.trace '------------------------------------------------------' // library marker rbn.common, line 1256
} // library marker rbn.common, line 1257
 // library marker rbn.common, line 1258
Object testJob() { // library marker rbn.common, line 1259
    log.warn 'test job executed' // library marker rbn.common, line 1260
} // library marker rbn.common, line 1261
 // library marker rbn.common, line 1262
/** // library marker rbn.common, line 1263
 * Calculates and returns the cron expression // library marker rbn.common, line 1264
 * @param timeInSeconds interval in seconds // library marker rbn.common, line 1265
 */ // library marker rbn.common, line 1266
String getCron(int timeInSeconds) { // library marker rbn.common, line 1267
    //schedule("${rnd.nextInt(59)} ${rnd.nextInt(9)}/${intervalMins} * ? * * *", 'ping') // library marker rbn.common, line 1268
    // TODO: runEvery1Minute runEvery5Minutes runEvery10Minutes runEvery15Minutes runEvery30Minutes runEvery1Hour runEvery3Hours // library marker rbn.common, line 1269
    final Random rnd = new Random() // library marker rbn.common, line 1270
    int minutes = (timeInSeconds / 60 ) as int // library marker rbn.common, line 1271
    int  hours = (minutes / 60 ) as int // library marker rbn.common, line 1272
    if (hours > 23) { hours = 23 } // library marker rbn.common, line 1273
    String cron // library marker rbn.common, line 1274
    if (timeInSeconds < 60) { cron = "*/$timeInSeconds * * * * ? *" } // library marker rbn.common, line 1275
    else { // library marker rbn.common, line 1276
        if (minutes < 60) {   cron = "${rnd.nextInt(59)} ${rnd.nextInt(9)}/$minutes * ? * *" } // library marker rbn.common, line 1277
        else {                cron = "${rnd.nextInt(59)} ${rnd.nextInt(59)} */$hours ? * *"  } // library marker rbn.common, line 1278
    } // library marker rbn.common, line 1279
    return cron // library marker rbn.common, line 1280
} // library marker rbn.common, line 1281
 // library marker rbn.common, line 1282
// credits @thebearmay // library marker rbn.common, line 1283
String formatUptime() { // library marker rbn.common, line 1284
    return formatTime(location.hub.uptime) // library marker rbn.common, line 1285
} // library marker rbn.common, line 1286
 // library marker rbn.common, line 1287
String formatTime(int timeInSeconds) { // library marker rbn.common, line 1288
    if (timeInSeconds == null) { return UNKNOWN } // library marker rbn.common, line 1289
    int days = (timeInSeconds / 86400).toInteger() // library marker rbn.common, line 1290
    int hours = ((timeInSeconds % 86400) / 3600).toInteger() // library marker rbn.common, line 1291
    int minutes = ((timeInSeconds % 3600) / 60).toInteger() // library marker rbn.common, line 1292
    int seconds = (timeInSeconds % 60).toInteger() // library marker rbn.common, line 1293
    return "${days}d ${hours}h ${minutes}m ${seconds}s" // library marker rbn.common, line 1294
} // library marker rbn.common, line 1295
 // library marker rbn.common, line 1296
boolean isAqara() { return device.getDataValue('model')?.startsWith('lumi') ?: false } // library marker rbn.common, line 1297
 // library marker rbn.common, line 1298
void updateAqaraVersion() { // library marker rbn.common, line 1299
    if (!isAqara()) { logTrace 'not Aqara' ; return } // library marker rbn.common, line 1300
    String application = device.getDataValue('application') // library marker rbn.common, line 1301
    if (application != null) { // library marker rbn.common, line 1302
        String str = '0.0.0_' + String.format('%04d', zigbee.convertHexToInt(application.take(2))) // library marker rbn.common, line 1303
        if (device.getDataValue('aqaraVersion') != str) { // library marker rbn.common, line 1304
            device.updateDataValue('aqaraVersion', str) // library marker rbn.common, line 1305
            logInfo "aqaraVersion set to $str" // library marker rbn.common, line 1306
        } // library marker rbn.common, line 1307
    } // library marker rbn.common, line 1308
} // library marker rbn.common, line 1309
 // library marker rbn.common, line 1310
String unix2formattedDate(Long unixTime) { // library marker rbn.common, line 1311
    try { // library marker rbn.common, line 1312
        if (unixTime == null) { return null } // library marker rbn.common, line 1313
        /* groovylint-disable-next-line NoJavaUtilDate */ // library marker rbn.common, line 1314
        Date date = new Date(unixTime.toLong()) // library marker rbn.common, line 1315
        return date.format('yyyy-MM-dd HH:mm:ss.SSS', location.timeZone) // library marker rbn.common, line 1316
    } catch (e) { // library marker rbn.common, line 1317
        logDebug "Error formatting date: ${e.message}. Returning current time instead." // library marker rbn.common, line 1318
        return new Date().format('yyyy-MM-dd HH:mm:ss.SSS', location.timeZone) // library marker rbn.common, line 1319
    } // library marker rbn.common, line 1320
} // library marker rbn.common, line 1321
 // library marker rbn.common, line 1322
Long formattedDate2unix(String formattedDate) { // library marker rbn.common, line 1323
    try { // library marker rbn.common, line 1324
        if (formattedDate == null) { return null } // library marker rbn.common, line 1325
        Date date = Date.parse('yyyy-MM-dd HH:mm:ss.SSS', formattedDate) // library marker rbn.common, line 1326
        return date.getTime() // library marker rbn.common, line 1327
    } catch (e) { // library marker rbn.common, line 1328
        logDebug "Error parsing formatted date: ${formattedDate}. Returning current time instead." // library marker rbn.common, line 1329
        return now() // library marker rbn.common, line 1330
    } // library marker rbn.common, line 1331
} // library marker rbn.common, line 1332
 // library marker rbn.common, line 1333
static String timeToHMS(final int time) { // library marker rbn.common, line 1334
    int hours = (time / 3600) as int // library marker rbn.common, line 1335
    int minutes = ((time % 3600) / 60) as int // library marker rbn.common, line 1336
    int seconds = time % 60 // library marker rbn.common, line 1337
    return "${hours}h ${minutes}m ${seconds}s" // library marker rbn.common, line 1338
} // library marker rbn.common, line 1339
// ~~~~~ end include rbn.common ~~~~~

// ~~~~~ start include rbn.switch ~~~~~
/* groovylint-disable CompileStatic, CouldBeSwitchStatement, DuplicateListLiteral, DuplicateMapLiteral, DuplicateNumberLiteral, DuplicateStringLiteral, ImplicitClosureParameter, ImplicitReturnStatement, Instanceof, LineLength, MethodCount, MethodSize, NoDouble, NoFloat, NoWildcardImports, ParameterCount, ParameterName, PublicMethodsBeforeNonPublicMethods, UnnecessaryElseStatement, UnnecessaryGetter, UnnecessaryObjectReferences, UnnecessaryPublicModifier, UnnecessarySetter, UnusedImport */ // library marker rbn.switch, line 1
library( // library marker rbn.switch, line 2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee OnOff Cluster Library', name: 'switch', namespace: 'rbn', // library marker rbn.switch, line 3
    importUrl: '', documentationLink: '', // library marker rbn.switch, line 4
    version: '3.2.4' // library marker rbn.switch, line 5
) // library marker rbn.switch, line 6
/* // library marker rbn.switch, line 7
 *  Zigbee OnOff Cluster Library // library marker rbn.switch, line 8
 * // library marker rbn.switch, line 9
 *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except // library marker rbn.switch, line 10
 *  in compliance with the License. You may obtain a copy of the License at: // library marker rbn.switch, line 11
 * // library marker rbn.switch, line 12
 *      http://www.apache.org/licenses/LICENSE-2.0 // library marker rbn.switch, line 13
 * // library marker rbn.switch, line 14
 *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed // library marker rbn.switch, line 15
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License // library marker rbn.switch, line 16
 *  for the specific language governing permissions and limitations under the License. // library marker rbn.switch, line 17
 * // library marker rbn.switch, line 18
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/onOffLib.groovy) at commit 0bf47407. // library marker rbn.switch, line 19
 *  Modified for the rbn namespace: Tuya 0xEF00 switch branch removed from on()/off(); identity. // library marker rbn.switch, line 20
 * // library marker rbn.switch, line 21
 * ver. 3.2.0  2024-06-04 kkossev  - commonLib 3.2.1 allignment; if isRefresh then sendEvent with isStateChange = true // library marker rbn.switch, line 22
 * ver. 3.2.1  2024-06-07 kkossev  - the advanced options are excpluded for DEVICE_TYPE Thermostat // library marker rbn.switch, line 23
 * ver. 3.2.2  2024-06-29 kkossev  - added on/off control for Tuya device profiles with 'switch' dp; // library marker rbn.switch, line 24
 * ver. 3.2.3  2025-12-06 kkossev  - fixed a bug in off() and on() methods where clearIsDigital() was called too early // library marker rbn.switch, line 25
 * ver. 3.2.4  2026-08-23 kkossev  - bug fix: quoted the respondsTo('getDEVICE') argument in on() and off(); the bare identifier threw a NullPointerException in drivers without deviceProfileLib // library marker rbn.switch, line 26
 * // library marker rbn.switch, line 27
 *                                   TODO: // library marker rbn.switch, line 28
*/ // library marker rbn.switch, line 29
 // library marker rbn.switch, line 30
static String onOffLibVersion()   { '3.2.4' } // library marker rbn.switch, line 31
static String onOffLibStamp() { '2026/08/23 4:27 PM' } // library marker rbn.switch, line 32
 // library marker rbn.switch, line 33
@Field static final Boolean _THREE_STATE = true // library marker rbn.switch, line 34
 // library marker rbn.switch, line 35
metadata { // library marker rbn.switch, line 36
    capability 'Actuator' // library marker rbn.switch, line 37
    capability 'Switch' // library marker rbn.switch, line 38
    if (_THREE_STATE == true) { // library marker rbn.switch, line 39
        attribute 'switch', 'enum', SwitchThreeStateOpts.options.values() as List<String> // library marker rbn.switch, line 40
    } // library marker rbn.switch, line 41
    // no commands // library marker rbn.switch, line 42
    preferences { // library marker rbn.switch, line 43
        if (settings?.advancedOptions == true && device != null && !(DEVICE_TYPE in ['Device', 'Thermostat'])) { // library marker rbn.switch, line 44
            input(name: 'ignoreDuplicated', type: 'bool', title: '<b>Ignore Duplicated Switch Events</b>', description: 'Some switches and plugs send periodically the switch status as a heart-beet ', defaultValue: true) // library marker rbn.switch, line 45
            input(name: 'alwaysOn', type: 'bool', title: '<b>Always On</b>', description: 'Disable switching off plugs and switches that must stay always On', defaultValue: false) // library marker rbn.switch, line 46
            if (_THREE_STATE == true) { // library marker rbn.switch, line 47
                input name: 'threeStateEnable', type: 'bool', title: '<b>Enable three-states events</b>', description: 'Experimental multi-state switch events', defaultValue: false // library marker rbn.switch, line 48
            } // library marker rbn.switch, line 49
        } // library marker rbn.switch, line 50
    } // library marker rbn.switch, line 51
} // library marker rbn.switch, line 52
 // library marker rbn.switch, line 53
@Field static final Map SwitchThreeStateOpts = [ // library marker rbn.switch, line 54
    defaultValue: 0, options: [0: 'off', 1: 'on', 2: 'switching_off', 3: 'switching_on', 4: 'switch_failure'] // library marker rbn.switch, line 55
] // library marker rbn.switch, line 56
 // library marker rbn.switch, line 57
@Field static final Map powerOnBehaviourOptions = [ // library marker rbn.switch, line 58
    '0': 'switch off', '1': 'switch on', '2': 'switch last state' // library marker rbn.switch, line 59
] // library marker rbn.switch, line 60
 // library marker rbn.switch, line 61
@Field static final Map switchTypeOptions = [ // library marker rbn.switch, line 62
    '0': 'toggle', '1': 'state', '2': 'momentary' // library marker rbn.switch, line 63
] // library marker rbn.switch, line 64
 // library marker rbn.switch, line 65
private boolean isCircuitBreaker()      { device.getDataValue('manufacturer') in ['_TZ3000_ky0fq4ho'] } // library marker rbn.switch, line 66
 // library marker rbn.switch, line 67
/* // library marker rbn.switch, line 68
 * ----------------------------------------------------------------------------- // library marker rbn.switch, line 69
 * on/off cluster            0x0006     TODO - move to a library !!!!!!!!!!!!!!! // library marker rbn.switch, line 70
 * ----------------------------------------------------------------------------- // library marker rbn.switch, line 71
*/ // library marker rbn.switch, line 72
void standardParseOnOffCluster(final Map descMap) { // library marker rbn.switch, line 73
    /* // library marker rbn.switch, line 74
    if (this.respondsTo('customParseOnOffCluster')) { // library marker rbn.switch, line 75
        customParseOnOffCluster(descMap) // library marker rbn.switch, line 76
    } // library marker rbn.switch, line 77
    else */ // library marker rbn.switch, line 78
    if (descMap.attrId == '0000') { // library marker rbn.switch, line 79
        if (descMap.value == null || descMap.value == 'FFFF') { logDebug "parseOnOffCluster: invalid value: ${descMap.value}"; return } // invalid or unknown value // library marker rbn.switch, line 80
        int rawValue = hexStrToUnsignedInt(descMap.value) // library marker rbn.switch, line 81
        sendSwitchEvent(rawValue) // library marker rbn.switch, line 82
    } // library marker rbn.switch, line 83
    else if (descMap.attrId in ['4000', '4001', '4002', '4004', '8000', '8001', '8002', '8003']) { // library marker rbn.switch, line 84
        parseOnOffAttributes(descMap) // library marker rbn.switch, line 85
    } // library marker rbn.switch, line 86
    else { // library marker rbn.switch, line 87
        if (descMap.attrId != null) { logWarn "standardParseOnOffCluster: unprocessed attrId ${descMap.attrId}"  } // library marker rbn.switch, line 88
        else { logDebug "standardParseOnOffCluster: skipped processing OnOff cluster (attrId is ${descMap.attrId})" } // ZigUSB has its own interpretation of the Zigbee standards ... :( // library marker rbn.switch, line 89
    } // library marker rbn.switch, line 90
} // library marker rbn.switch, line 91
 // library marker rbn.switch, line 92
void toggleX() { // library marker rbn.switch, line 93
    String descriptionText = 'central button switch is ' // library marker rbn.switch, line 94
    String state = '' // library marker rbn.switch, line 95
    if ((device.currentState('switch')?.value ?: 'n/a') == 'off') { // library marker rbn.switch, line 96
        state = 'on' // library marker rbn.switch, line 97
    } // library marker rbn.switch, line 98
    else { // library marker rbn.switch, line 99
        state = 'off' // library marker rbn.switch, line 100
    } // library marker rbn.switch, line 101
    descriptionText += state // library marker rbn.switch, line 102
    sendEvent(name: 'switch', value: state, descriptionText: descriptionText, type: 'physical', isStateChange: true) // library marker rbn.switch, line 103
    logInfo "${descriptionText}" // library marker rbn.switch, line 104
} // library marker rbn.switch, line 105
 // library marker rbn.switch, line 106
void off() { // library marker rbn.switch, line 107
    if (this.respondsTo('customOff')) { customOff() ; return  } // library marker rbn.switch, line 108
    if ((settings?.alwaysOn ?: false) == true) { logWarn "AlwaysOn option for ${device.displayName} is enabled , the command to switch it OFF is ignored!" ; return } // library marker rbn.switch, line 109
    List<String> cmds = (settings?.inverceSwitch == null || settings?.inverceSwitch == false) ?  zigbee.off()  : zigbee.on() // library marker rbn.switch, line 110
 // library marker rbn.switch, line 111
    String currentState = device.currentState('switch')?.value ?: 'n/a' // library marker rbn.switch, line 112
    logDebug "off() currentState=${currentState}" // library marker rbn.switch, line 113
    if (_THREE_STATE == true && settings?.threeStateEnable == true) { // library marker rbn.switch, line 114
        if (currentState == 'off') { // library marker rbn.switch, line 115
            runIn(1, 'refresh',  [overwrite: true]) // library marker rbn.switch, line 116
        } // library marker rbn.switch, line 117
        String value = SwitchThreeStateOpts.options[2]    // 'switching_on' // library marker rbn.switch, line 118
        String descriptionText = "${value}" // library marker rbn.switch, line 119
        if (logEnable) { descriptionText += ' (2)' } // library marker rbn.switch, line 120
        sendEvent(name: 'switch', value: value, descriptionText: descriptionText, type: 'digital', isStateChange: true) // library marker rbn.switch, line 121
        logInfo "${descriptionText}" // library marker rbn.switch, line 122
    } // library marker rbn.switch, line 123
    state.states['isDigital'] = true // library marker rbn.switch, line 124
    runInMillis(DIGITAL_TIMER, clearIsDigital, [overwrite: true]) // library marker rbn.switch, line 125
    sendZigbeeCommands(cmds) // library marker rbn.switch, line 126
} // library marker rbn.switch, line 127
 // library marker rbn.switch, line 128
void on() { // library marker rbn.switch, line 129
    if (this.respondsTo('customOn')) { customOn() ; return } // library marker rbn.switch, line 130
    List<String> cmds = (settings?.inverceSwitch == null || settings?.inverceSwitch == false) ?  zigbee.on()  : zigbee.off() // library marker rbn.switch, line 131
    String currentState = device.currentState('switch')?.value ?: 'n/a' // library marker rbn.switch, line 132
    logDebug "on() currentState=${currentState}" // library marker rbn.switch, line 133
    if (_THREE_STATE == true && settings?.threeStateEnable == true) { // library marker rbn.switch, line 134
        if ((device.currentState('switch')?.value ?: 'n/a') == 'on') { // library marker rbn.switch, line 135
            runIn(1, 'refresh',  [overwrite: true]) // library marker rbn.switch, line 136
        } // library marker rbn.switch, line 137
        String value = SwitchThreeStateOpts.options[3]    // 'switching_on' // library marker rbn.switch, line 138
        String descriptionText = "${value}" // library marker rbn.switch, line 139
        if (logEnable) { descriptionText += ' (2)' } // library marker rbn.switch, line 140
        sendEvent(name: 'switch', value: value, descriptionText: descriptionText, type: 'digital', isStateChange: true) // library marker rbn.switch, line 141
        logInfo "${descriptionText}" // library marker rbn.switch, line 142
    } // library marker rbn.switch, line 143
    state.states['isDigital'] = true // library marker rbn.switch, line 144
    runInMillis(DIGITAL_TIMER, clearIsDigital, [overwrite: true]) // library marker rbn.switch, line 145
    sendZigbeeCommands(cmds) // library marker rbn.switch, line 146
} // library marker rbn.switch, line 147
 // library marker rbn.switch, line 148
void sendSwitchEvent(int switchValuePar) { // library marker rbn.switch, line 149
    int switchValue = safeToInt(switchValuePar) // library marker rbn.switch, line 150
    if (settings?.inverceSwitch != null && settings?.inverceSwitch == true) { // library marker rbn.switch, line 151
        switchValue = (switchValue == 0x00) ? 0x01 : 0x00 // library marker rbn.switch, line 152
    } // library marker rbn.switch, line 153
    String value = (switchValue == null) ? 'unknown' : (switchValue == 0x00) ? 'off' : (switchValue == 0x01) ? 'on' : 'unknown' // library marker rbn.switch, line 154
    Map map = [:] // library marker rbn.switch, line 155
    boolean isRefresh = state.states['isRefresh'] ?: false // library marker rbn.switch, line 156
    boolean debounce = state.states['debounce'] ?: false // library marker rbn.switch, line 157
    String lastSwitch = state.states['lastSwitch'] ?: 'unknown' // library marker rbn.switch, line 158
    if (value == lastSwitch && (debounce || (settings.ignoreDuplicated ?: false)) && !isRefresh) { // library marker rbn.switch, line 159
        logDebug "Ignored duplicated switch event ${value}" // library marker rbn.switch, line 160
        runInMillis(DEBOUNCING_TIMER, switchDebouncingClear, [overwrite: true]) // library marker rbn.switch, line 161
        return // library marker rbn.switch, line 162
    } // library marker rbn.switch, line 163
    logTrace "value=${value}  lastSwitch=${state.states['lastSwitch']}" // library marker rbn.switch, line 164
    boolean isDigital = state.states['isDigital'] ?: false // library marker rbn.switch, line 165
    map.type = isDigital ? 'digital' : 'physical' // library marker rbn.switch, line 166
    if (lastSwitch != value) { // library marker rbn.switch, line 167
        logDebug "switch state changed from <b>${lastSwitch}</b> to <b>${value}</b>" // library marker rbn.switch, line 168
        state.states['debounce'] = true // library marker rbn.switch, line 169
        state.states['lastSwitch'] = value // library marker rbn.switch, line 170
        runInMillis(DEBOUNCING_TIMER, switchDebouncingClear, [overwrite: true]) // library marker rbn.switch, line 171
    } else { // library marker rbn.switch, line 172
        state.states['debounce'] = true // library marker rbn.switch, line 173
        runInMillis(DEBOUNCING_TIMER, switchDebouncingClear, [overwrite: true]) // library marker rbn.switch, line 174
    } // library marker rbn.switch, line 175
    map.name = 'switch' // library marker rbn.switch, line 176
    map.value = value // library marker rbn.switch, line 177
    if (isRefresh) { // library marker rbn.switch, line 178
        map.descriptionText = "${device.displayName} is ${value} [Refresh]" // library marker rbn.switch, line 179
        map.isStateChange = true // library marker rbn.switch, line 180
    } else { // library marker rbn.switch, line 181
        map.descriptionText = "${device.displayName} is ${value} [${map.type}]" // library marker rbn.switch, line 182
    } // library marker rbn.switch, line 183
    logInfo "${map.descriptionText}" // library marker rbn.switch, line 184
    sendEvent(map) // library marker rbn.switch, line 185
    if (this.respondsTo('customSwitchEventPostProcesing')) { // library marker rbn.switch, line 186
        customSwitchEventPostProcesing(map) // library marker rbn.switch, line 187
    } // library marker rbn.switch, line 188
} // library marker rbn.switch, line 189
 // library marker rbn.switch, line 190
void parseOnOffAttributes(final Map it) { // library marker rbn.switch, line 191
    logDebug "OnOff attribute ${it.attrId} cluster ${it.cluster } reported: value=${it.value}" // library marker rbn.switch, line 192
    /* groovylint-disable-next-line VariableTypeRequired */ // library marker rbn.switch, line 193
    String mode // library marker rbn.switch, line 194
    String attrName // library marker rbn.switch, line 195
    if (it.value == null) { // library marker rbn.switch, line 196
        logDebug "OnOff attribute ${it.attrId} cluster ${it.cluster } skipping NULL value status=${it.status}" // library marker rbn.switch, line 197
        return // library marker rbn.switch, line 198
    } // library marker rbn.switch, line 199
    int value = zigbee.convertHexToInt(it.value) // library marker rbn.switch, line 200
    switch (it.attrId) { // library marker rbn.switch, line 201
        case '4000' :    // non-Tuya GlobalSceneControl (bool), read-only // library marker rbn.switch, line 202
            attrName = 'Global Scene Control' // library marker rbn.switch, line 203
            mode = value == 0 ? 'off' : value == 1 ? 'on' : null // library marker rbn.switch, line 204
            break // library marker rbn.switch, line 205
        case '4001' :    // non-Tuya OnTime (UINT16), read-only // library marker rbn.switch, line 206
            attrName = 'On Time' // library marker rbn.switch, line 207
            mode = value // library marker rbn.switch, line 208
            break // library marker rbn.switch, line 209
        case '4002' :    // non-Tuya OffWaitTime (UINT16), read-only // library marker rbn.switch, line 210
            attrName = 'Off Wait Time' // library marker rbn.switch, line 211
            mode = value // library marker rbn.switch, line 212
            break // library marker rbn.switch, line 213
        case '4003' :    // non-Tuya "powerOnState" (ENUM8), read-write, default=1 // library marker rbn.switch, line 214
            attrName = 'Power On State' // library marker rbn.switch, line 215
            mode = value == 0 ? 'off' : value == 1 ? 'on' : value == 2 ?  'Last state' : 'UNKNOWN' // library marker rbn.switch, line 216
            break // library marker rbn.switch, line 217
        case '8000' :    // command "childLock", [[name:"Child Lock", type: "ENUM", description: "Select Child Lock mode", constraints: ["off", "on"]]] // library marker rbn.switch, line 218
            attrName = 'Child Lock' // library marker rbn.switch, line 219
            mode = value == 0 ? 'off' : 'on' // library marker rbn.switch, line 220
            break // library marker rbn.switch, line 221
        case '8001' :    // command "ledMode", [[name:"LED mode", type: "ENUM", description: "Select LED mode", constraints: ["Disabled", "Lit when On", "Lit when Off", "Always Green", "Red when On; Green when Off", "Green when On; Red when Off", "Always Red" ]]] // library marker rbn.switch, line 222
            attrName = 'LED mode' // library marker rbn.switch, line 223
            if (isCircuitBreaker()) { // library marker rbn.switch, line 224
                mode = value == 0 ? 'Always Green' : value == 1 ? 'Red when On; Green when Off' : value == 2 ? 'Green when On; Red when Off' : value == 3 ? 'Always Red' : null // library marker rbn.switch, line 225
            } // library marker rbn.switch, line 226
            else { // library marker rbn.switch, line 227
                mode = value == 0 ? 'Disabled' : value == 1 ? 'Lit when On' : value == 2 ? 'Lit when Off' : value == 3 ? 'Freeze' : null // library marker rbn.switch, line 228
            } // library marker rbn.switch, line 229
            break // library marker rbn.switch, line 230
        case '8002' :    // command "powerOnState", [[name:"Power On State", type: "ENUM", description: "Select Power On State", constraints: ["off","on", "Last state"]]] // library marker rbn.switch, line 231
            attrName = 'Power On State' // library marker rbn.switch, line 232
            mode = value == 0 ? 'off' : value == 1 ? 'on' : value == 2 ?  'Last state' : null // library marker rbn.switch, line 233
            break // library marker rbn.switch, line 234
        case '8003' : //  Over current alarm // library marker rbn.switch, line 235
            attrName = 'Over current alarm' // library marker rbn.switch, line 236
            mode = value == 0 ? 'Over Current OK' : value == 1 ? 'Over Current Alarm' : null // library marker rbn.switch, line 237
            break // library marker rbn.switch, line 238
        default : // library marker rbn.switch, line 239
            logWarn "Unprocessed Tuya OnOff attribute ${it.attrId} cluster ${it.cluster } reported: value=${it.value}" // library marker rbn.switch, line 240
            return // library marker rbn.switch, line 241
    } // library marker rbn.switch, line 242
    if (settings?.logEnable) { logInfo "${attrName} is ${mode}" } // library marker rbn.switch, line 243
} // library marker rbn.switch, line 244
 // library marker rbn.switch, line 245
List<String> onOffRefresh() { // library marker rbn.switch, line 246
    logDebug 'onOffRefresh()' // library marker rbn.switch, line 247
    List<String> cmds = zigbee.readAttribute(0x0006, 0x0000, [:], delay = 100) // library marker rbn.switch, line 248
    return cmds // library marker rbn.switch, line 249
} // library marker rbn.switch, line 250
 // library marker rbn.switch, line 251
void onOfInitializeVars( boolean fullInit = false ) { // library marker rbn.switch, line 252
    logDebug "onOfInitializeVars()... fullInit = ${fullInit}" // library marker rbn.switch, line 253
    if (fullInit || settings?.ignoreDuplicated == null) { device.updateSetting('ignoreDuplicated', true) } // library marker rbn.switch, line 254
    if (fullInit || settings?.alwaysOn == null) { device.updateSetting('alwaysOn', false) } // library marker rbn.switch, line 255
    if ((fullInit || settings?.threeStateEnable == null) && _THREE_STATE == true) { device.updateSetting('threeStateEnable', false) } // library marker rbn.switch, line 256
} // library marker rbn.switch, line 257
// ~~~~~ end include rbn.switch ~~~~~

// ~~~~~ start include rbn.xiaomi ~~~~~
/* groovylint-disable CompileStatic, DuplicateListLiteral, DuplicateMapLiteral, DuplicateNumberLiteral, DuplicateStringLiteral, ImplicitReturnStatement, LineLength, PublicMethodsBeforeNonPublicMethods, UnnecessaryGetter, UnnecessaryPublicModifier */ // library marker rbn.xiaomi, line 1
library( // library marker rbn.xiaomi, line 2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Xiaomi Library', name: 'xiaomi', namespace: 'rbn', importUrl: '', documentationLink: '', // library marker rbn.xiaomi, line 3
    version: '3.3.0' // library marker rbn.xiaomi, line 4
) // library marker rbn.xiaomi, line 5
/* // library marker rbn.xiaomi, line 6
 *  Xiaomi Library // library marker rbn.xiaomi, line 7
 * // library marker rbn.xiaomi, line 8
 *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except // library marker rbn.xiaomi, line 9
 *  in compliance with the License. You may obtain a copy of the License at: // library marker rbn.xiaomi, line 10
 * // library marker rbn.xiaomi, line 11
 *      http://www.apache.org/licenses/LICENSE-2.0 // library marker rbn.xiaomi, line 12
 * // library marker rbn.xiaomi, line 13
 *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed // library marker rbn.xiaomi, line 14
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License // library marker rbn.xiaomi, line 15
 *  for the specific language governing permissions and limitations under the License. // library marker rbn.xiaomi, line 16
 * // library marker rbn.xiaomi, line 17
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/xiaomiLib.groovy) at commit 0bf47407. // library marker rbn.xiaomi, line 18
 *  Modified for the rbn namespace: identity changes only. // library marker rbn.xiaomi, line 19
 * // library marker rbn.xiaomi, line 20
 * ver. 1.0.0  2023-09-09 kkossev  - added xiaomiLib // library marker rbn.xiaomi, line 21
 * ver. 1.0.1  2023-11-07 kkossev  - (dev. branch) // library marker rbn.xiaomi, line 22
 * ver. 1.0.2  2024-04-06 kkossev  - (dev. branch) Groovy linting; aqaraCube specific code; // library marker rbn.xiaomi, line 23
 * ver. 1.1.0  2024-06-01 kkossev  - (dev. branch) comonLib 3.2.0 alignmment // library marker rbn.xiaomi, line 24
 * ver. 3.2.2  2024-06-01 kkossev  - (dev. branch) comonLib 3.2.2 alignmment // library marker rbn.xiaomi, line 25
 * ver. 3.3.0  2024-06-23 kkossev  - comonLib 3.3.0 alignmment; added parseXiaomiClusterSingeTag() method // library marker rbn.xiaomi, line 26
 * // library marker rbn.xiaomi, line 27
 *                                   TODO: remove the DEVICE_TYPE dependencies for Bulb, Thermostat, AqaraCube, FP1, TRV_OLD // library marker rbn.xiaomi, line 28
 *                                   TODO: remove the isAqaraXXX  dependencies !! // library marker rbn.xiaomi, line 29
*/ // library marker rbn.xiaomi, line 30
 // library marker rbn.xiaomi, line 31
static String xiaomiLibVersion()   { '3.3.0' } // library marker rbn.xiaomi, line 32
static String xiaomiLibStamp() { '2024/06/23 9:36 AM' } // library marker rbn.xiaomi, line 33
 // library marker rbn.xiaomi, line 34
boolean isAqaraTVOC_Lib()  { (device?.getDataValue('model') ?: 'n/a') in ['lumi.airmonitor.acn01'] } // library marker rbn.xiaomi, line 35
boolean isAqaraTVOC_OLD()  { (device?.getDataValue('model') ?: 'n/a') in ['lumi.airmonitor.acn01'] } // library marker rbn.xiaomi, line 36
boolean isAqaraCube()  { (device?.getDataValue('model') ?: 'n/a') in ['lumi.remote.cagl02'] } // library marker rbn.xiaomi, line 37
boolean isAqaraFP1()   { (device?.getDataValue('model') ?: 'n/a') in ['lumi.motion.ac01'] } // library marker rbn.xiaomi, line 38
boolean isAqaraTRV_OLD()   { (device?.getDataValue('model') ?: 'n/a') in ['lumi.airrtc.agl001'] } // library marker rbn.xiaomi, line 39
 // library marker rbn.xiaomi, line 40
// no metadata for this library! // library marker rbn.xiaomi, line 41
 // library marker rbn.xiaomi, line 42
@Field static final int XIAOMI_CLUSTER_ID = 0xFCC0 // library marker rbn.xiaomi, line 43
 // library marker rbn.xiaomi, line 44
// Zigbee Attributes // library marker rbn.xiaomi, line 45
@Field static final int DIRECTION_MODE_ATTR_ID = 0x0144 // library marker rbn.xiaomi, line 46
@Field static final int MODEL_ATTR_ID = 0x05 // library marker rbn.xiaomi, line 47
@Field static final int PRESENCE_ACTIONS_ATTR_ID = 0x0143 // library marker rbn.xiaomi, line 48
@Field static final int PRESENCE_ATTR_ID = 0x0142 // library marker rbn.xiaomi, line 49
@Field static final int REGION_EVENT_ATTR_ID = 0x0151 // library marker rbn.xiaomi, line 50
@Field static final int RESET_PRESENCE_ATTR_ID = 0x0157 // library marker rbn.xiaomi, line 51
@Field static final int SENSITIVITY_LEVEL_ATTR_ID = 0x010C // library marker rbn.xiaomi, line 52
@Field static final int SET_EDGE_REGION_ATTR_ID = 0x0156 // library marker rbn.xiaomi, line 53
@Field static final int SET_EXIT_REGION_ATTR_ID = 0x0153 // library marker rbn.xiaomi, line 54
@Field static final int SET_INTERFERENCE_ATTR_ID = 0x0154 // library marker rbn.xiaomi, line 55
@Field static final int SET_REGION_ATTR_ID = 0x0150 // library marker rbn.xiaomi, line 56
@Field static final int TRIGGER_DISTANCE_ATTR_ID = 0x0146 // library marker rbn.xiaomi, line 57
@Field static final int XIAOMI_RAW_ATTR_ID = 0xFFF2 // library marker rbn.xiaomi, line 58
@Field static final int XIAOMI_SPECIAL_REPORT_ID = 0x00F7 // library marker rbn.xiaomi, line 59
@Field static final Map MFG_CODE = [ mfgCode: 0x115F ] // library marker rbn.xiaomi, line 60
 // library marker rbn.xiaomi, line 61
// Xiaomi Tags // library marker rbn.xiaomi, line 62
@Field static final int DIRECTION_MODE_TAG_ID = 0x67 // library marker rbn.xiaomi, line 63
@Field static final int SENSITIVITY_LEVEL_TAG_ID = 0x66 // library marker rbn.xiaomi, line 64
@Field static final int SWBUILD_TAG_ID = 0x08 // library marker rbn.xiaomi, line 65
@Field static final int TRIGGER_DISTANCE_TAG_ID = 0x69 // library marker rbn.xiaomi, line 66
@Field static final int PRESENCE_ACTIONS_TAG_ID = 0x66 // library marker rbn.xiaomi, line 67
@Field static final int PRESENCE_TAG_ID = 0x65 // library marker rbn.xiaomi, line 68
 // library marker rbn.xiaomi, line 69
// called from parseXiaomiCluster() in the main code, if no customParse is defined // library marker rbn.xiaomi, line 70
// TODO - refactor AqaraCube specific code // library marker rbn.xiaomi, line 71
// TODO - refactor for Thermostat and Bulb specific code // library marker rbn.xiaomi, line 72
void standardParseXiaomiFCC0Cluster(final Map descMap) { // library marker rbn.xiaomi, line 73
    if (settings.logEnable) { // library marker rbn.xiaomi, line 74
        logTrace "standardParseXiaomiFCC0Cluster: zigbee received xiaomi cluster attribute 0x${descMap.attrId} (value ${descMap.value})" // library marker rbn.xiaomi, line 75
    } // library marker rbn.xiaomi, line 76
    if (DEVICE_TYPE in  ['Thermostat']) { // library marker rbn.xiaomi, line 77
        parseXiaomiClusterThermostatLib(descMap) // library marker rbn.xiaomi, line 78
        return // library marker rbn.xiaomi, line 79
    } // library marker rbn.xiaomi, line 80
    if (DEVICE_TYPE in  ['Bulb']) { // library marker rbn.xiaomi, line 81
        parseXiaomiClusterRgbLib(descMap) // library marker rbn.xiaomi, line 82
        return // library marker rbn.xiaomi, line 83
    } // library marker rbn.xiaomi, line 84
    // TODO - refactor AqaraCube specific code // library marker rbn.xiaomi, line 85
    // TODO - refactor FP1 specific code // library marker rbn.xiaomi, line 86
    final String funcName = 'standardParseXiaomiFCC0Cluster' // library marker rbn.xiaomi, line 87
    switch (descMap.attrInt as Integer) { // library marker rbn.xiaomi, line 88
        case 0x0009:                      // Aqara Cube T1 Pro // library marker rbn.xiaomi, line 89
            if (DEVICE_TYPE in  ['AqaraCube']) { logDebug "standardParseXiaomiFCC0Cluster: AqaraCube 0xFCC0 attribute 0x009 value is ${hexStrToUnsignedInt(descMap.value)}" } // library marker rbn.xiaomi, line 90
            else { logDebug "${funcName}: unknown attribute ${descMap.attrInt} value raw = ${hexStrToUnsignedInt(descMap.value)}" } // library marker rbn.xiaomi, line 91
            break // library marker rbn.xiaomi, line 92
        case 0x00FC:                      // FP1 // library marker rbn.xiaomi, line 93
            logWarn "${funcName}: unknown attribute - resetting?" // library marker rbn.xiaomi, line 94
            break // library marker rbn.xiaomi, line 95
        case PRESENCE_ATTR_ID:            // 0x0142 FP1 // library marker rbn.xiaomi, line 96
            final Integer value = hexStrToUnsignedInt(descMap.value) // library marker rbn.xiaomi, line 97
            parseXiaomiClusterPresence(value) // library marker rbn.xiaomi, line 98
            break // library marker rbn.xiaomi, line 99
        case PRESENCE_ACTIONS_ATTR_ID:    // 0x0143 FP1 // library marker rbn.xiaomi, line 100
            final Integer value = hexStrToUnsignedInt(descMap.value) // library marker rbn.xiaomi, line 101
            parseXiaomiClusterPresenceAction(value) // library marker rbn.xiaomi, line 102
            break // library marker rbn.xiaomi, line 103
        case REGION_EVENT_ATTR_ID:        // 0x0151 FP1 // library marker rbn.xiaomi, line 104
            // Region events can be sent fast and furious so buffer them // library marker rbn.xiaomi, line 105
            final Integer regionId = HexUtils.hexStringToInt(descMap.value[0..1]) // library marker rbn.xiaomi, line 106
            final Integer value = HexUtils.hexStringToInt(descMap.value[2..3]) // library marker rbn.xiaomi, line 107
            if (settings.logEnable) { // library marker rbn.xiaomi, line 108
                log.debug "${funcName}: xiaomi: region ${regionId} action is ${value}" // library marker rbn.xiaomi, line 109
            } // library marker rbn.xiaomi, line 110
            if (device.currentValue("region${regionId}") != null) { // library marker rbn.xiaomi, line 111
                RegionUpdateBuffer.get(device.id).put(regionId, value) // library marker rbn.xiaomi, line 112
                runInMillis(REGION_UPDATE_DELAY_MS, 'updateRegions') // library marker rbn.xiaomi, line 113
            } // library marker rbn.xiaomi, line 114
            break // library marker rbn.xiaomi, line 115
        case SENSITIVITY_LEVEL_ATTR_ID:   // 0x010C FP1 // library marker rbn.xiaomi, line 116
            final Integer value = hexStrToUnsignedInt(descMap.value) // library marker rbn.xiaomi, line 117
            log.info "sensitivity level is '${SensitivityLevelOpts.options[value]}' (0x${descMap.value})" // library marker rbn.xiaomi, line 118
            device.updateSetting('sensitivityLevel', [value: value.toString(), type: 'enum']) // library marker rbn.xiaomi, line 119
            break // library marker rbn.xiaomi, line 120
        case TRIGGER_DISTANCE_ATTR_ID:    // 0x0146 FP1 // library marker rbn.xiaomi, line 121
            final Integer value = hexStrToUnsignedInt(descMap.value) // library marker rbn.xiaomi, line 122
            log.info "approach distance is '${ApproachDistanceOpts.options[value]}' (0x${descMap.value})" // library marker rbn.xiaomi, line 123
            device.updateSetting('approachDistance', [value: value.toString(), type: 'enum']) // library marker rbn.xiaomi, line 124
            break // library marker rbn.xiaomi, line 125
        case DIRECTION_MODE_ATTR_ID:     // 0x0144 FP1 // library marker rbn.xiaomi, line 126
            final Integer value = hexStrToUnsignedInt(descMap.value) // library marker rbn.xiaomi, line 127
            log.info "monitoring direction mode is '${DirectionModeOpts.options[value]}' (0x${descMap.value})" // library marker rbn.xiaomi, line 128
            device.updateSetting('directionMode', [value: value.toString(), type: 'enum']) // library marker rbn.xiaomi, line 129
            break // library marker rbn.xiaomi, line 130
        case 0x0148 :                    // Aqara Cube T1 Pro - Mode // library marker rbn.xiaomi, line 131
            if (DEVICE_TYPE in  ['AqaraCube']) { parseXiaomiClusterAqaraCube(descMap) } // library marker rbn.xiaomi, line 132
            else { logDebug "${funcName}: unknown attribute ${descMap.attrInt} value raw = ${hexStrToUnsignedInt(descMap.value)}" } // library marker rbn.xiaomi, line 133
            break // library marker rbn.xiaomi, line 134
        case 0x0149:                     // (329) Aqara Cube T1 Pro - i side facing up (0..5) // library marker rbn.xiaomi, line 135
            if (DEVICE_TYPE in  ['AqaraCube']) { parseXiaomiClusterAqaraCube(descMap) } // library marker rbn.xiaomi, line 136
            else { logDebug "${funcName}: unknown attribute ${descMap.attrInt} value raw = ${hexStrToUnsignedInt(descMap.value)}" } // library marker rbn.xiaomi, line 137
            break // library marker rbn.xiaomi, line 138
        case XIAOMI_SPECIAL_REPORT_ID:   // 0x00F7 sent every 55 minutes // library marker rbn.xiaomi, line 139
            final Map<Integer, Integer> tags = decodeXiaomiTags(descMap.value) // library marker rbn.xiaomi, line 140
            parseXiaomiClusterTags(tags) // library marker rbn.xiaomi, line 141
            if (isAqaraCube()) { // library marker rbn.xiaomi, line 142
                sendZigbeeCommands(customRefresh()) // library marker rbn.xiaomi, line 143
            } // library marker rbn.xiaomi, line 144
            break // library marker rbn.xiaomi, line 145
        case XIAOMI_RAW_ATTR_ID:        // 0xFFF2 FP1 // library marker rbn.xiaomi, line 146
            final byte[] rawData = HexUtils.hexStringToByteArray(descMap.value) // library marker rbn.xiaomi, line 147
            if (rawData.size() == 24 && settings.enableDistanceDirection) { // library marker rbn.xiaomi, line 148
                final int degrees = rawData[19] // library marker rbn.xiaomi, line 149
                final int distanceCm = (rawData[17] << 8) | (rawData[18] & 0x00ff) // library marker rbn.xiaomi, line 150
                if (settings.logEnable) { // library marker rbn.xiaomi, line 151
                    log.debug "location ${degrees}&deg;, ${distanceCm}cm" // library marker rbn.xiaomi, line 152
                } // library marker rbn.xiaomi, line 153
                runIn(1, 'updateLocation', [ data: [ degrees: degrees, distanceCm: distanceCm ] ]) // library marker rbn.xiaomi, line 154
            } // library marker rbn.xiaomi, line 155
            break // library marker rbn.xiaomi, line 156
        default: // library marker rbn.xiaomi, line 157
            log.warn "${funcName}: zigbee received unknown xiaomi cluster 0xFCC0 attribute 0x${descMap.attrId} (value ${descMap.value})" // library marker rbn.xiaomi, line 158
            break // library marker rbn.xiaomi, line 159
    } // library marker rbn.xiaomi, line 160
} // library marker rbn.xiaomi, line 161
 // library marker rbn.xiaomi, line 162
// cluster 0xFCC0 attribute  0x00F7 is sent as a keep-alive beakon every 55 minutes // library marker rbn.xiaomi, line 163
public void parseXiaomiClusterTags(final Map<Integer, Object> tags) { // library marker rbn.xiaomi, line 164
    final String funcName = 'parseXiaomiClusterTags' // library marker rbn.xiaomi, line 165
    tags.each { final Integer tag, final Object value -> // library marker rbn.xiaomi, line 166
        parseXiaomiClusterSingeTag(tag, value) // library marker rbn.xiaomi, line 167
    } // library marker rbn.xiaomi, line 168
} // library marker rbn.xiaomi, line 169
 // library marker rbn.xiaomi, line 170
public void parseXiaomiClusterSingeTag(final Integer tag, final Object value) { // library marker rbn.xiaomi, line 171
    final String funcName = 'parseXiaomiClusterSingeTag' // library marker rbn.xiaomi, line 172
    switch (tag) { // library marker rbn.xiaomi, line 173
        case 0x01:    // battery voltage // library marker rbn.xiaomi, line 174
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} battery voltage is ${value / 1000}V (raw=${value})" // library marker rbn.xiaomi, line 175
            break // library marker rbn.xiaomi, line 176
        case 0x03: // library marker rbn.xiaomi, line 177
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} device temperature is ${value}&deg;" // library marker rbn.xiaomi, line 178
            break // library marker rbn.xiaomi, line 179
        case 0x05: // library marker rbn.xiaomi, line 180
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} RSSI is ${value}" // library marker rbn.xiaomi, line 181
            break // library marker rbn.xiaomi, line 182
        case 0x06: // library marker rbn.xiaomi, line 183
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} LQI is ${value}" // library marker rbn.xiaomi, line 184
            break // library marker rbn.xiaomi, line 185
        case 0x08:            // SWBUILD_TAG_ID: // library marker rbn.xiaomi, line 186
            final String swBuild = '0.0.0_' + (value & 0xFF).toString().padLeft(4, '0') // library marker rbn.xiaomi, line 187
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} swBuild is ${swBuild} (raw ${value})" // library marker rbn.xiaomi, line 188
            device.updateDataValue('aqaraVersion', swBuild) // library marker rbn.xiaomi, line 189
            break // library marker rbn.xiaomi, line 190
        case 0x0a: // library marker rbn.xiaomi, line 191
            String nwk = intToHexStr(value as Integer, 2) // library marker rbn.xiaomi, line 192
            if (state.health == null) { state.health = [:] } // library marker rbn.xiaomi, line 193
            String oldNWK = state.health['parentNWK'] ?: 'n/a' // library marker rbn.xiaomi, line 194
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} <b>Parent NWK is ${nwk}</b>" // library marker rbn.xiaomi, line 195
            if (oldNWK != nwk ) { // library marker rbn.xiaomi, line 196
                logWarn "parentNWK changed from ${oldNWK} to ${nwk}" // library marker rbn.xiaomi, line 197
                state.health['parentNWK']  = nwk // library marker rbn.xiaomi, line 198
                state.health['nwkCtr'] = (state.health['nwkCtr'] ?: 0) + 1 // library marker rbn.xiaomi, line 199
            } // library marker rbn.xiaomi, line 200
            break // library marker rbn.xiaomi, line 201
        case 0x0b: // library marker rbn.xiaomi, line 202
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} light level is ${value}" // library marker rbn.xiaomi, line 203
            break // library marker rbn.xiaomi, line 204
        case 0x64: // library marker rbn.xiaomi, line 205
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} temperature is ${value / 100} (raw ${value})"    // Aqara TVOC // library marker rbn.xiaomi, line 206
            // TODO - also smoke gas/density if UINT ! // library marker rbn.xiaomi, line 207
            break // library marker rbn.xiaomi, line 208
        case 0x65: // library marker rbn.xiaomi, line 209
            if (isAqaraFP1()) { logDebug "${funcName} PRESENCE_TAG_ID tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 210
            else              { logDebug "xiaomi decode tag: 0x${intToHexStr(tag, 1)} humidity is ${value / 100} (raw ${value})" }    // Aqara TVOC // library marker rbn.xiaomi, line 211
            break // library marker rbn.xiaomi, line 212
        case 0x66: // library marker rbn.xiaomi, line 213
            if (isAqaraFP1()) { logDebug "${funcName} SENSITIVITY_LEVEL_TAG_ID tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 214
            else if (isAqaraTVOC_Lib()) { logDebug "xiaomi decode tag: 0x${intToHexStr(tag, 1)} airQualityIndex is ${value}" }        // Aqara TVOC level (in ppb) // library marker rbn.xiaomi, line 215
            else                    { logDebug "xiaomi decode tag: 0x${intToHexStr(tag, 1)} presure is ${value}" } // library marker rbn.xiaomi, line 216
            break // library marker rbn.xiaomi, line 217
        case 0x67: // library marker rbn.xiaomi, line 218
            if (isAqaraFP1()) { logDebug "${funcName} DIRECTION_MODE_TAG_ID tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 219
            else              { logDebug "${funcName} unknown tag: 0x${intToHexStr(tag, 1)}=${value}" }                        // Aqara TVOC: // library marker rbn.xiaomi, line 220
            // air quality (as 6 - #stars) ['excellent', 'good', 'moderate', 'poor', 'unhealthy'][val - 1] // library marker rbn.xiaomi, line 221
            break // library marker rbn.xiaomi, line 222
        case 0x69: // library marker rbn.xiaomi, line 223
            if (isAqaraFP1()) { logDebug "${funcName} TRIGGER_DISTANCE_TAG_ID tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 224
            else              { logDebug "${funcName} unknown tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 225
            break // library marker rbn.xiaomi, line 226
        case 0x6a: // library marker rbn.xiaomi, line 227
            if (isAqaraFP1()) { logDebug "${funcName} FP1 unknown tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 228
            else              { logDebug "${funcName} MOTION SENSITIVITY tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 229
            break // library marker rbn.xiaomi, line 230
        case 0x6b: // library marker rbn.xiaomi, line 231
            if (isAqaraFP1()) { logDebug "${funcName} FP1 unknown tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 232
            else              { logDebug "${funcName} MOTION LED tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 233
            break // library marker rbn.xiaomi, line 234
        case 0x95: // library marker rbn.xiaomi, line 235
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} energy is ${value}" // library marker rbn.xiaomi, line 236
            break // library marker rbn.xiaomi, line 237
        case 0x96: // library marker rbn.xiaomi, line 238
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} voltage is ${value}" // library marker rbn.xiaomi, line 239
            break // library marker rbn.xiaomi, line 240
        case 0x97: // library marker rbn.xiaomi, line 241
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} current is ${value}" // library marker rbn.xiaomi, line 242
            break // library marker rbn.xiaomi, line 243
        case 0x98: // library marker rbn.xiaomi, line 244
            logDebug "${funcName}: 0x${intToHexStr(tag, 1)} power is ${value}" // library marker rbn.xiaomi, line 245
            break // library marker rbn.xiaomi, line 246
        case 0x9b: // library marker rbn.xiaomi, line 247
            if (isAqaraCube()) { // library marker rbn.xiaomi, line 248
                logDebug "${funcName} Aqara cubeMode tag: 0x${intToHexStr(tag, 1)} is '${AqaraCubeModeOpts.options[value as int]}' (${value})" // library marker rbn.xiaomi, line 249
                sendAqaraCubeOperationModeEvent(value as int) // library marker rbn.xiaomi, line 250
            } // library marker rbn.xiaomi, line 251
            else { logDebug "${funcName} CONSUMER CONNECTED tag: 0x${intToHexStr(tag, 1)}=${value}" } // library marker rbn.xiaomi, line 252
            break // library marker rbn.xiaomi, line 253
        default: // library marker rbn.xiaomi, line 254
            logDebug "${funcName} unknown tag: 0x${intToHexStr(tag, 1)}=${value}" // library marker rbn.xiaomi, line 255
    } // library marker rbn.xiaomi, line 256
} // library marker rbn.xiaomi, line 257
 // library marker rbn.xiaomi, line 258
/** // library marker rbn.xiaomi, line 259
 *  Reads a specified number of little-endian bytes from a given // library marker rbn.xiaomi, line 260
 *  ByteArrayInputStream and returns a BigInteger. // library marker rbn.xiaomi, line 261
 */ // library marker rbn.xiaomi, line 262
private static BigInteger readBigIntegerBytes(final ByteArrayInputStream stream, final int length) { // library marker rbn.xiaomi, line 263
    final byte[] byteArr = new byte[length] // library marker rbn.xiaomi, line 264
    stream.read(byteArr, 0, length) // library marker rbn.xiaomi, line 265
    BigInteger bigInt = BigInteger.ZERO // library marker rbn.xiaomi, line 266
    for (int i = byteArr.length - 1; i >= 0; i--) { // library marker rbn.xiaomi, line 267
        bigInt |= (BigInteger.valueOf((byteArr[i] & 0xFF) << (8 * i))) // library marker rbn.xiaomi, line 268
    } // library marker rbn.xiaomi, line 269
    return bigInt // library marker rbn.xiaomi, line 270
} // library marker rbn.xiaomi, line 271
 // library marker rbn.xiaomi, line 272
/** // library marker rbn.xiaomi, line 273
 *  Decodes a Xiaomi Zigbee cluster attribute payload in hexadecimal format and // library marker rbn.xiaomi, line 274
 *  returns a map of decoded tag number and value pairs where the value is either a // library marker rbn.xiaomi, line 275
 *  BigInteger for fixed values or a String for variable length. // library marker rbn.xiaomi, line 276
 */ // library marker rbn.xiaomi, line 277
private Map<Integer, Object> decodeXiaomiTags(final String hexString) { // library marker rbn.xiaomi, line 278
    try { // library marker rbn.xiaomi, line 279
        final Map<Integer, Object> results = [:] // library marker rbn.xiaomi, line 280
        final byte[] bytes = HexUtils.hexStringToByteArray(hexString) // library marker rbn.xiaomi, line 281
        new ByteArrayInputStream(bytes).withCloseable { final stream -> // library marker rbn.xiaomi, line 282
            while (stream.available() > 2) { // library marker rbn.xiaomi, line 283
                int tag = stream.read() // library marker rbn.xiaomi, line 284
                int dataType = stream.read() // library marker rbn.xiaomi, line 285
                Object value // library marker rbn.xiaomi, line 286
                if (DataType.isDiscrete(dataType)) { // library marker rbn.xiaomi, line 287
                    int length = stream.read() // library marker rbn.xiaomi, line 288
                    byte[] byteArr = new byte[length] // library marker rbn.xiaomi, line 289
                    stream.read(byteArr, 0, length) // library marker rbn.xiaomi, line 290
                    value = new String(byteArr) // library marker rbn.xiaomi, line 291
                } else { // library marker rbn.xiaomi, line 292
                    int length = DataType.getLength(dataType) // library marker rbn.xiaomi, line 293
                    value = readBigIntegerBytes(stream, length) // library marker rbn.xiaomi, line 294
                } // library marker rbn.xiaomi, line 295
                results[tag] = value // library marker rbn.xiaomi, line 296
            } // library marker rbn.xiaomi, line 297
        } // library marker rbn.xiaomi, line 298
        return results // library marker rbn.xiaomi, line 299
    } // library marker rbn.xiaomi, line 300
    catch (e) { // library marker rbn.xiaomi, line 301
        if (settings.logEnable) { "${device.displayName} decodeXiaomiTags: ${e}" } // library marker rbn.xiaomi, line 302
        return [:] // library marker rbn.xiaomi, line 303
    } // library marker rbn.xiaomi, line 304
} // library marker rbn.xiaomi, line 305
 // library marker rbn.xiaomi, line 306
List<String> refreshXiaomi() { // library marker rbn.xiaomi, line 307
    List<String> cmds = [] // library marker rbn.xiaomi, line 308
    if (cmds == []) { cmds = ['delay 299'] } // library marker rbn.xiaomi, line 309
    return cmds // library marker rbn.xiaomi, line 310
} // library marker rbn.xiaomi, line 311
 // library marker rbn.xiaomi, line 312
List<String> configureXiaomi() { // library marker rbn.xiaomi, line 313
    List<String> cmds = [] // library marker rbn.xiaomi, line 314
    logDebug "configureXiaomi() : ${cmds}" // library marker rbn.xiaomi, line 315
    if (cmds == []) { cmds = ['delay 299'] }    // no , // library marker rbn.xiaomi, line 316
    return cmds // library marker rbn.xiaomi, line 317
} // library marker rbn.xiaomi, line 318
 // library marker rbn.xiaomi, line 319
List<String> initializeXiaomi() { // library marker rbn.xiaomi, line 320
    List<String> cmds = [] // library marker rbn.xiaomi, line 321
    logDebug "initializeXiaomi() : ${cmds}" // library marker rbn.xiaomi, line 322
    if (cmds == []) { cmds = ['delay 299',] } // library marker rbn.xiaomi, line 323
    return cmds // library marker rbn.xiaomi, line 324
} // library marker rbn.xiaomi, line 325
 // library marker rbn.xiaomi, line 326
void initVarsXiaomi(boolean fullInit=false) { // library marker rbn.xiaomi, line 327
    logDebug "initVarsXiaomi(${fullInit})" // library marker rbn.xiaomi, line 328
} // library marker rbn.xiaomi, line 329
 // library marker rbn.xiaomi, line 330
void initEventsXiaomi(boolean fullInit=false) { // library marker rbn.xiaomi, line 331
    logDebug "initEventsXiaomi(${fullInit})" // library marker rbn.xiaomi, line 332
} // library marker rbn.xiaomi, line 333
 // library marker rbn.xiaomi, line 334
List<String> standardAqaraBlackMagic() { // library marker rbn.xiaomi, line 335
    return [] // library marker rbn.xiaomi, line 336
    ///////////////////////////////////////// // library marker rbn.xiaomi, line 337
    List<String> cmds = [] // library marker rbn.xiaomi, line 338
    if (isAqaraTVOC_OLD() || isAqaraTRV_OLD()) { // library marker rbn.xiaomi, line 339
        cmds += ["he raw 0x${device.deviceNetworkId} 0 0 0x8002 {40 00 00 00 00 40 8f 5f 11 52 52 00 41 2c 52 00 00} {0x0000}", 'delay 200',] // library marker rbn.xiaomi, line 340
        cmds += "zdo bind 0x${device.deviceNetworkId} 0x01 0x01 0xFCC0 {${device.zigbeeId}} {}" // library marker rbn.xiaomi, line 341
        cmds += "zdo bind 0x${device.deviceNetworkId} 0x01 0x01 0x0406 {${device.zigbeeId}} {}" // library marker rbn.xiaomi, line 342
        cmds += zigbee.readAttribute(0x0001, 0x0020, [:], delay = 200)    // TODO: check - battery voltage // library marker rbn.xiaomi, line 343
        if (isAqaraTVOC_OLD()) { // library marker rbn.xiaomi, line 344
            cmds += zigbee.readAttribute(0xFCC0, [0x0102, 0x010C], [mfgCode: 0x115F], delay = 200)    // TVOC only // library marker rbn.xiaomi, line 345
        } // library marker rbn.xiaomi, line 346
        logDebug 'standardAqaraBlackMagic()' // library marker rbn.xiaomi, line 347
    } // library marker rbn.xiaomi, line 348
    return cmds // library marker rbn.xiaomi, line 349
} // library marker rbn.xiaomi, line 350
// ~~~~~ end include rbn.xiaomi ~~~~~

// ~~~~~ start include rbn.button ~~~~~
/* groovylint-disable CompileStatic, CouldBeSwitchStatement, DuplicateListLiteral, DuplicateNumberLiteral, DuplicateStringLiteral, ImplicitClosureParameter, ImplicitReturnStatement, Instanceof, LineLength, MethodCount, MethodSize, NoDouble, NoFloat, NoWildcardImports, ParameterCount, ParameterName, UnnecessaryElseStatement, UnnecessaryGetter, UnnecessaryPublicModifier, UnnecessarySetter, UnusedImport */ // library marker rbn.button, line 1
library( // library marker rbn.button, line 2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee Button Library', name: 'button', namespace: 'rbn', // library marker rbn.button, line 3
    importUrl: '', documentationLink: '', // library marker rbn.button, line 4
    version: '3.2.0' // library marker rbn.button, line 5
) // library marker rbn.button, line 6
/* // library marker rbn.button, line 7
 *  Zigbee Button Library // library marker rbn.button, line 8
 * // library marker rbn.button, line 9
 *  Licensed Virtual the Apache License, Version 2.0 (the "License"); you may not use this file except // library marker rbn.button, line 10
 *  in compliance with the License. You may obtain a copy of the License at: // library marker rbn.button, line 11
 * // library marker rbn.button, line 12
 *      http://www.apache.org/licenses/LICENSE-2.0 // library marker rbn.button, line 13
 * // library marker rbn.button, line 14
 *  Unless required by applicable law or agreed to in writing, software distributed under the License is distributed // library marker rbn.button, line 15
 *  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License // library marker rbn.button, line 16
 *  for the specific language governing permissions and limitations under the License. // library marker rbn.button, line 17
 * // library marker rbn.button, line 18
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/buttonLib.groovy) at commit 0bf47407. // library marker rbn.button, line 19
 *  Modified for the rbn namespace: identity changes only. // library marker rbn.button, line 20
 * // library marker rbn.button, line 21
 * ver. 3.0.0  2024-04-06 kkossev  - added energyLib.groovy // library marker rbn.button, line 22
 * ver. 3.2.0  2024-05-24 kkossev  - commonLib 3.2.0 allignment; added capability 'PushableButton' and 'Momentary' // library marker rbn.button, line 23
 * // library marker rbn.button, line 24
 *                                   TODO: // library marker rbn.button, line 25
*/ // library marker rbn.button, line 26
 // library marker rbn.button, line 27
static String buttonLibVersion()   { '3.2.0' } // library marker rbn.button, line 28
static String buttonLibStamp() { '2024/05/24 12:48 PM' } // library marker rbn.button, line 29
 // library marker rbn.button, line 30
metadata { // library marker rbn.button, line 31
    capability 'PushableButton' // library marker rbn.button, line 32
    capability 'Momentary' // library marker rbn.button, line 33
    // the other capabilities must be declared in the custom driver, if applicable for the particular device! // library marker rbn.button, line 34
    // the custom driver must allso call sendNumberOfButtonsEvent() and sendSupportedButtonValuesEvent()! // library marker rbn.button, line 35
    // capability 'DoubleTapableButton' // library marker rbn.button, line 36
    // capability 'HoldableButton' // library marker rbn.button, line 37
    // capability 'ReleasableButton' // library marker rbn.button, line 38
 // library marker rbn.button, line 39
    // no attributes // library marker rbn.button, line 40
    // no commands // library marker rbn.button, line 41
    preferences { // library marker rbn.button, line 42
        // no prefrences // library marker rbn.button, line 43
    } // library marker rbn.button, line 44
} // library marker rbn.button, line 45
 // library marker rbn.button, line 46
void sendButtonEvent(int buttonNumber, String buttonState, boolean isDigital=false) { // library marker rbn.button, line 47
    if (buttonState != 'unknown' && buttonNumber != 0) { // library marker rbn.button, line 48
        String descriptionText = "button $buttonNumber was $buttonState" // library marker rbn.button, line 49
        if (isDigital) { descriptionText += ' [digital]' } // library marker rbn.button, line 50
        Map event = [name: buttonState, value: buttonNumber.toString(), data: [buttonNumber: buttonNumber], descriptionText: descriptionText, isStateChange: true, type: isDigital == true ? 'digital' : 'physical'] // library marker rbn.button, line 51
        logInfo "$descriptionText" // library marker rbn.button, line 52
        sendEvent(event) // library marker rbn.button, line 53
    } // library marker rbn.button, line 54
    else { // library marker rbn.button, line 55
        logWarn "sendButtonEvent: UNHANDLED event for button ${buttonNumber}, buttonState=${buttonState}" // library marker rbn.button, line 56
    } // library marker rbn.button, line 57
} // library marker rbn.button, line 58
 // library marker rbn.button, line 59
void push() {                // Momentary capability // library marker rbn.button, line 60
    logDebug 'push momentary' // library marker rbn.button, line 61
    if (this.respondsTo('customPush')) { customPush(); return } // library marker rbn.button, line 62
    logWarn "push() not implemented for ${(DEVICE_TYPE)}" // library marker rbn.button, line 63
} // library marker rbn.button, line 64
 // library marker rbn.button, line 65
/* // library marker rbn.button, line 66
void push(BigDecimal buttonNumber) {    //pushableButton capability // library marker rbn.button, line 67
    logDebug "push button $buttonNumber" // library marker rbn.button, line 68
    if (this.respondsTo('customPush')) { customPush(buttonNumber); return } // library marker rbn.button, line 69
    sendButtonEvent(buttonNumber as int, 'pushed', isDigital = true) // library marker rbn.button, line 70
} // library marker rbn.button, line 71
*/ // library marker rbn.button, line 72
 // library marker rbn.button, line 73
void push(Object bn) {    //pushableButton capability // library marker rbn.button, line 74
    Integer buttonNumber = bn.toInteger() // library marker rbn.button, line 75
    logDebug "push button $buttonNumber" // library marker rbn.button, line 76
    if (this.respondsTo('customPush')) { customPush(buttonNumber); return } // library marker rbn.button, line 77
    sendButtonEvent(buttonNumber as int, 'pushed', isDigital = true) // library marker rbn.button, line 78
} // library marker rbn.button, line 79
 // library marker rbn.button, line 80
void doubleTap(Object bn) { // library marker rbn.button, line 81
    Integer buttonNumber = bn.toInteger() // library marker rbn.button, line 82
    sendButtonEvent(buttonNumber as int, 'doubleTapped', isDigital = true) // library marker rbn.button, line 83
} // library marker rbn.button, line 84
 // library marker rbn.button, line 85
void hold(Object bn) { // library marker rbn.button, line 86
    Integer buttonNumber = bn.toInteger() // library marker rbn.button, line 87
    sendButtonEvent(buttonNumber as int, 'held', isDigital = true) // library marker rbn.button, line 88
} // library marker rbn.button, line 89
 // library marker rbn.button, line 90
void release(Object bn) { // library marker rbn.button, line 91
    Integer buttonNumber = bn.toInteger() // library marker rbn.button, line 92
    sendButtonEvent(buttonNumber as int, 'released', isDigital = true) // library marker rbn.button, line 93
} // library marker rbn.button, line 94
 // library marker rbn.button, line 95
// must be called from the custom driver! // library marker rbn.button, line 96
void sendNumberOfButtonsEvent(int numberOfButtons) { // library marker rbn.button, line 97
    sendEvent(name: 'numberOfButtons', value: numberOfButtons, isStateChange: true, type: 'digital') // library marker rbn.button, line 98
} // library marker rbn.button, line 99
// must be called from the custom driver! // library marker rbn.button, line 100
void sendSupportedButtonValuesEvent(List<String> supportedValues) { // library marker rbn.button, line 101
    sendEvent(name: 'supportedButtonValues', value: JsonOutput.toJson(supportedValues), isStateChange: true, type: 'digital') // library marker rbn.button, line 102
} // library marker rbn.button, line 103
 // library marker rbn.button, line 104
// ~~~~~ end include rbn.button ~~~~~

// ~~~~~ start include rbn.battery ~~~~~
/* groovylint-disable CompileStatic, CouldBeSwitchStatement, DuplicateListLiteral, DuplicateNumberLiteral, DuplicateStringLiteral, ImplicitClosureParameter, ImplicitReturnStatement, Instanceof, LineLength, MethodCount, MethodSize, NoDouble, NoFloat, NoJavaUtilDate, NoWildcardImports, ParameterCount, ParameterName, PublicMethodsBeforeNonPublicMethods, UnnecessaryElseStatement, UnnecessaryGetter, UnnecessaryObjectReferences, UnnecessaryPublicModifier, UnnecessarySetter, UnusedImport */ // library marker rbn.battery, line 1
library( // library marker rbn.battery, line 2
    base: 'driver', author: 'Krassimir Kossev', category: 'zigbee', description: 'Zigbee Battery Library', name: 'battery', namespace: 'rbn', // library marker rbn.battery, line 3
    importUrl: '', documentationLink: '', // library marker rbn.battery, line 4
    version: '3.2.4' // library marker rbn.battery, line 5
) // library marker rbn.battery, line 6
/* // library marker rbn.battery, line 7
 *  Zigbee Battery Library // library marker rbn.battery, line 8
 * // library marker rbn.battery, line 9
 *  Licensed Virtual the Apache License, Version 2.0 // library marker rbn.battery, line 10
 * // library marker rbn.battery, line 11
 *  Forked from https://github.com/kkossev/Hubitat (Libraries/batteryLib.groovy) at commit 0bf47407. // library marker rbn.battery, line 12
 *  Modified for the rbn namespace: isTuya() branch and Tuya battery-level helpers removed; identity. // library marker rbn.battery, line 13
 * // library marker rbn.battery, line 14
 * ver. 3.0.0  2024-04-06 kkossev  - added batteryLib.groovy // library marker rbn.battery, line 15
 * ver. 3.0.1  2024-04-06 kkossev  - customParsePowerCluster bug fix // library marker rbn.battery, line 16
 * ver. 3.0.2  2024-04-14 kkossev  - batteryPercentage bug fix (was x2); added bVoltCtr; added battertRefresh // library marker rbn.battery, line 17
 * ver. 3.2.0  2024-05-21 kkossev  - commonLib 3.2.0 allignment; added lastBattery; added handleTuyaBatteryLevel // library marker rbn.battery, line 18
 * ver. 3.2.1  2024-07-06 kkossev  - added tuyaToBatteryLevel and handleTuyaBatteryLevel; added batteryInitializeVars // library marker rbn.battery, line 19
 * ver. 3.2.2  2024-07-18 kkossev  - added BatteryVoltage and BatteryDelay device capability checks // library marker rbn.battery, line 20
 * ver. 3.2.3  2025-07-13 kkossev  - bug fix: corrected runIn method name from 'sendDelayedBatteryEvent' to 'sendDelayedBatteryPercentageEvent' // library marker rbn.battery, line 21
 * ver. 3.2.4  2026-08-23 kkossev  - bug fix: non-Tuya battery percentage is now rounded instead of truncated (raw 1 was reported as 0%) // library marker rbn.battery, line 22
 * // library marker rbn.battery, line 23
 *                                   TODO: add an Advanced Option resetBatteryToZeroWhenOffline // library marker rbn.battery, line 24
 *                                   TODO: battery voltage low/high limits configuration // library marker rbn.battery, line 25
*/ // library marker rbn.battery, line 26
 // library marker rbn.battery, line 27
static String batteryLibVersion()   { '3.2.4' } // library marker rbn.battery, line 28
static String batteryLibStamp() { '2026/08/23 3:43 PM' } // library marker rbn.battery, line 29
 // library marker rbn.battery, line 30
metadata { // library marker rbn.battery, line 31
    capability 'Battery' // library marker rbn.battery, line 32
    attribute  'batteryVoltage', 'number' // library marker rbn.battery, line 33
    attribute  'lastBattery', 'date'         // last battery event time - added in 3.2.0 05/21/2024 // library marker rbn.battery, line 34
    // no commands // library marker rbn.battery, line 35
    preferences { // library marker rbn.battery, line 36
        if (device && advancedOptions == true) { // library marker rbn.battery, line 37
            if ('BatteryVoltage' in DEVICE?.capabilities) { // library marker rbn.battery, line 38
                input name: 'voltageToPercent', type: 'bool', title: '<b>Battery Voltage to Percentage</b>', defaultValue: false, description: 'Convert battery voltage to battery Percentage remaining.' // library marker rbn.battery, line 39
            } // library marker rbn.battery, line 40
            if ('BatteryDelay' in DEVICE?.capabilities) { // library marker rbn.battery, line 41
                input(name: 'batteryDelay', type: 'enum', title: '<b>Battery Events Delay</b>', description:'Select the Battery Events Delay<br>(default is <b>no delay</b>)', options: DelayBatteryOpts.options, defaultValue: DelayBatteryOpts.defaultValue) // library marker rbn.battery, line 42
            } // library marker rbn.battery, line 43
        } // library marker rbn.battery, line 44
    } // library marker rbn.battery, line 45
} // library marker rbn.battery, line 46
 // library marker rbn.battery, line 47
@Field static final Map DelayBatteryOpts = [ defaultValue: 0, options: [0: 'No delay', 30: '30 seconds', 3600: '1 hour', 14400: '4 hours', 28800: '8 hours', 43200: '12 hours']] // library marker rbn.battery, line 48
 // library marker rbn.battery, line 49
public void standardParsePowerCluster(final Map descMap) { // library marker rbn.battery, line 50
    if (descMap.value == null || descMap.value == 'FFFF') { return } // invalid or unknown value // library marker rbn.battery, line 51
    final int rawValue = hexStrToUnsignedInt(descMap.value) // library marker rbn.battery, line 52
    if (descMap.attrId == '0020') { // battery voltage // library marker rbn.battery, line 53
        state.lastRx['batteryTime'] = new Date().getTime() // library marker rbn.battery, line 54
        state.stats['bVoltCtr'] = (state.stats['bVoltCtr'] ?: 0) + 1 // library marker rbn.battery, line 55
        sendBatteryVoltageEvent(rawValue) // library marker rbn.battery, line 56
        if ((settings.voltageToPercent ?: false) == true) { // library marker rbn.battery, line 57
            sendBatteryVoltageEvent(rawValue, convertToPercent = true) // library marker rbn.battery, line 58
        } // library marker rbn.battery, line 59
    } // library marker rbn.battery, line 60
    else if (descMap.attrId == '0021') { // battery percentage // library marker rbn.battery, line 61
        state.lastRx['batteryTime'] = new Date().getTime() // library marker rbn.battery, line 62
        state.stats['battCtr'] = (state.stats['battCtr'] ?: 0) + 1 // library marker rbn.battery, line 63
        sendBatteryPercentageEvent(Math.round(rawValue / 2.0) as int) // library marker rbn.battery, line 64
    } // library marker rbn.battery, line 65
    else { // library marker rbn.battery, line 66
        logWarn "customParsePowerCluster: zigbee received unknown Power cluster attribute 0x${descMap.attrId} (value ${descMap.value})" // library marker rbn.battery, line 67
    } // library marker rbn.battery, line 68
} // library marker rbn.battery, line 69
 // library marker rbn.battery, line 70
public void sendBatteryVoltageEvent(final int rawValue, boolean convertToPercent=false) { // library marker rbn.battery, line 71
    logDebug "batteryVoltage = ${(double)rawValue / 10.0} V" // library marker rbn.battery, line 72
    final Date lastBattery = new Date() // library marker rbn.battery, line 73
    Map result = [:] // library marker rbn.battery, line 74
    BigDecimal volts = safeToBigDecimal(rawValue) / 10G // library marker rbn.battery, line 75
    if (rawValue != 0 && rawValue != 255) { // library marker rbn.battery, line 76
        BigDecimal minVolts = 2.2 // library marker rbn.battery, line 77
        BigDecimal maxVolts = 3.2 // library marker rbn.battery, line 78
        BigDecimal pct = (volts - minVolts) / (maxVolts - minVolts) // library marker rbn.battery, line 79
        int roundedPct = Math.round(pct * 100) // library marker rbn.battery, line 80
        if (roundedPct <= 0) { roundedPct = 1 } // library marker rbn.battery, line 81
        if (roundedPct > 100) { roundedPct = 100 } // library marker rbn.battery, line 82
        if (convertToPercent == true) { // library marker rbn.battery, line 83
            result.value = Math.min(100, roundedPct) // library marker rbn.battery, line 84
            result.name = 'battery' // library marker rbn.battery, line 85
            result.unit  = '%' // library marker rbn.battery, line 86
            result.descriptionText = "battery is ${roundedPct} %" // library marker rbn.battery, line 87
        } // library marker rbn.battery, line 88
        else { // library marker rbn.battery, line 89
            result.value = volts // library marker rbn.battery, line 90
            result.name = 'batteryVoltage' // library marker rbn.battery, line 91
            result.unit  = 'V' // library marker rbn.battery, line 92
            result.descriptionText = "battery is ${volts} Volts" // library marker rbn.battery, line 93
        } // library marker rbn.battery, line 94
        result.type = 'physical' // library marker rbn.battery, line 95
        result.isStateChange = true // library marker rbn.battery, line 96
        logInfo "${result.descriptionText}" // library marker rbn.battery, line 97
        sendEvent(result) // library marker rbn.battery, line 98
        sendEvent(name: 'lastBattery', value: lastBattery) // library marker rbn.battery, line 99
    } // library marker rbn.battery, line 100
    else { // library marker rbn.battery, line 101
        logWarn "ignoring BatteryResult(${rawValue})" // library marker rbn.battery, line 102
    } // library marker rbn.battery, line 103
} // library marker rbn.battery, line 104
 // library marker rbn.battery, line 105
public void sendBatteryPercentageEvent(final int batteryPercent, boolean isDigital=false) { // library marker rbn.battery, line 106
    if ((batteryPercent as int) == 255) { // library marker rbn.battery, line 107
        logWarn "ignoring battery report raw=${batteryPercent}" // library marker rbn.battery, line 108
        return // library marker rbn.battery, line 109
    } // library marker rbn.battery, line 110
    final Date lastBattery = new Date() // library marker rbn.battery, line 111
    Map map = [:] // library marker rbn.battery, line 112
    map.name = 'battery' // library marker rbn.battery, line 113
    map.timeStamp = now() // library marker rbn.battery, line 114
    map.value = batteryPercent < 0 ? 0 : batteryPercent > 100 ? 100 : (batteryPercent as int) // library marker rbn.battery, line 115
    map.unit  = '%' // library marker rbn.battery, line 116
    map.type = isDigital ? 'digital' : 'physical' // library marker rbn.battery, line 117
    map.descriptionText = "${map.name} is ${map.value} ${map.unit}" // library marker rbn.battery, line 118
    map.isStateChange = true // library marker rbn.battery, line 119
    // // library marker rbn.battery, line 120
    Object latestBatteryEvent = device.currentState('battery') // library marker rbn.battery, line 121
    Long latestBatteryEventTime = latestBatteryEvent != null ? latestBatteryEvent.getDate().getTime() : now() // library marker rbn.battery, line 122
    //log.debug "battery latest state timeStamp is ${latestBatteryTime} now is ${now()}" // library marker rbn.battery, line 123
    int timeDiff = ((now() - latestBatteryEventTime) / 1000) as int // library marker rbn.battery, line 124
    if (settings?.batteryDelay == null || (settings?.batteryDelay as int) == 0 || timeDiff > (settings?.batteryDelay as int)) { // library marker rbn.battery, line 125
        // send it now! // library marker rbn.battery, line 126
        sendDelayedBatteryPercentageEvent(map) // library marker rbn.battery, line 127
        sendEvent(name: 'lastBattery', value: lastBattery) // library marker rbn.battery, line 128
    } // library marker rbn.battery, line 129
    else { // library marker rbn.battery, line 130
        int delayedTime = (settings?.batteryDelay as int) - timeDiff // library marker rbn.battery, line 131
        map.delayed = delayedTime // library marker rbn.battery, line 132
        map.descriptionText += " [delayed ${map.delayed} seconds]" // library marker rbn.battery, line 133
        map.lastBattery = lastBattery // library marker rbn.battery, line 134
        logDebug "this  battery event (${map.value}%) will be delayed ${delayedTime} seconds" // library marker rbn.battery, line 135
        runIn(delayedTime, 'sendDelayedBatteryPercentageEvent', [overwrite: true, data: map]) // library marker rbn.battery, line 136
    } // library marker rbn.battery, line 137
} // library marker rbn.battery, line 138
 // library marker rbn.battery, line 139
private void sendDelayedBatteryPercentageEvent(Map map) { // library marker rbn.battery, line 140
    logInfo "${map.descriptionText}" // library marker rbn.battery, line 141
    //map.each {log.trace "$it"} // library marker rbn.battery, line 142
    sendEvent(map) // library marker rbn.battery, line 143
    sendEvent(name: 'lastBattery', value: map.lastBattery) // library marker rbn.battery, line 144
} // library marker rbn.battery, line 145
 // library marker rbn.battery, line 146
/* groovylint-disable-next-line UnusedPrivateMethod */ // library marker rbn.battery, line 147
private void sendDelayedBatteryVoltageEvent(Map map) { // library marker rbn.battery, line 148
    logInfo "${map.descriptionText}" // library marker rbn.battery, line 149
    //map.each {log.trace "$it"} // library marker rbn.battery, line 150
    sendEvent(map) // library marker rbn.battery, line 151
    sendEvent(name: 'lastBattery', value: map.lastBattery) // library marker rbn.battery, line 152
} // library marker rbn.battery, line 153
 // library marker rbn.battery, line 154
public void batteryInitializeVars( boolean fullInit = false ) { // library marker rbn.battery, line 155
    logDebug "batteryInitializeVars()... fullInit = ${fullInit}" // library marker rbn.battery, line 156
    if (device.hasCapability('Battery')) { // library marker rbn.battery, line 157
        if (fullInit || settings?.voltageToPercent == null) { device.updateSetting('voltageToPercent', false) } // library marker rbn.battery, line 158
        if (fullInit || settings?.batteryDelay == null) { device.updateSetting('batteryDelay', [value: DelayBatteryOpts.defaultValue.toString(), type: 'enum']) } // library marker rbn.battery, line 159
    } // library marker rbn.battery, line 160
} // library marker rbn.battery, line 161
 // library marker rbn.battery, line 162
public List<String> batteryRefresh() { // library marker rbn.battery, line 163
    List<String> cmds = [] // library marker rbn.battery, line 164
    cmds += zigbee.readAttribute(0x0001, 0x0020, [:], delay = 100)         // battery voltage // library marker rbn.battery, line 165
    cmds += zigbee.readAttribute(0x0001, 0x0021, [:], delay = 100)         // battery percentage // library marker rbn.battery, line 166
    return cmds // library marker rbn.battery, line 167
} // library marker rbn.battery, line 168
// ~~~~~ end include rbn.battery ~~~~~
