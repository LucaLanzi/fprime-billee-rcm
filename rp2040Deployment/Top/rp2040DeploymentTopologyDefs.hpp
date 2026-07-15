// ======================================================================
// \title  rp2040DeploymentTopologyDefs.hpp
// \brief required header file containing the required definitions for the topology autocoder
// ======================================================================
#ifndef RP2040DEPLOYMENT_RP2040DEPLOYMENTTOPOLOGYDEFS_HPP
#define RP2040DEPLOYMENT_RP2040DEPLOYMENTTOPOLOGYDEFS_HPP

#include "Svc/Subtopologies/CdhCore/PingEntries.hpp"
#include "Svc/Subtopologies/ComFprime/PingEntries.hpp"

#include "Svc/Subtopologies/CdhCore/SubtopologyTopologyDefs.hpp"
#include "Svc/Subtopologies/ComFprime/SubtopologyTopologyDefs.hpp"

#include "Svc/Subtopologies/ComFprime/Ports_ComPacketQueueEnumAc.hpp"
#include "Svc/Subtopologies/ComFprime/Ports_ComBufferQueueEnumAc.hpp"

#include "rp2040Deployment/Top/FppConstantsAc.hpp"

namespace PingEntries {
    namespace rp2040Deployment_rateGroup1 {enum { WARN = 3, FATAL = 5 };}
}

namespace rp2040Deployment {

struct TopologyState {
    const char* uartDevice;
    U32 baudRate;
    CdhCore::SubtopologyState cdhCore;
    ComFprime::SubtopologyState comFprime;
};

namespace PingEntries = ::PingEntries;
}  // namespace rp2040Deployment

#endif
