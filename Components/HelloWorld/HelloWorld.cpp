// ======================================================================
// \title  HelloWorld.cpp
// \author luca_lanzi
// \brief  cpp file for HelloWorld component implementation class
// ======================================================================

#include "Components/HelloWorld/HelloWorld.hpp"

namespace FprimeBilleeRcm {

// ----------------------------------------------------------------------
// Component construction and destruction
// ----------------------------------------------------------------------

HelloWorld ::HelloWorld(const char* const compName) : HelloWorldComponentBase(compName) {}

HelloWorld ::~HelloWorld() {}

// ----------------------------------------------------------------------
// Handler implementations for commands
// ----------------------------------------------------------------------

void HelloWorld ::TODO_cmdHandler(FwOpcodeType opCode, U32 cmdSeq) {
    // TODO
    this->cmdResponse_out(opCode, cmdSeq, Fw::CmdResponse::OK);
}

}  // namespace FprimeBilleeRcm
