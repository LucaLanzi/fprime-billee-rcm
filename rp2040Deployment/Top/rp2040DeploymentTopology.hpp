// ======================================================================
// \title  rp2040DeploymentTopology.hpp
// \brief header file containing the topology instantiation definitions
// ======================================================================
#ifndef RP2040DEPLOYMENT_RP2040DEPLOYMENTTOPOLOGY_HPP
#define RP2040DEPLOYMENT_RP2040DEPLOYMENTTOPOLOGY_HPP

#include <rp2040Deployment/Top/rp2040DeploymentTopologyDefs.hpp>

namespace rp2040Deployment {

void setupTopology(const TopologyState& state);
void teardownTopology(const TopologyState& state);
void startRateGroups(const Fw::TimeInterval& interval = Fw::TimeInterval(1,0));
void stopRateGroups();

} // namespace rp2040Deployment
#endif
