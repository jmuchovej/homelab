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

#include rbn.common
#include rbn.switch
#include rbn.level
#include rbn.meter
#include rbn.reporting

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
