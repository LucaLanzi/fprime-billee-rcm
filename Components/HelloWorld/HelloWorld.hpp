// ======================================================================
// \title  HelloWorld.hpp
// \author luca_lanzi
// \brief  hpp file for HelloWorld component implementation class
// ======================================================================

#ifndef FprimeBilleeRcm_HelloWorld_HPP
#define FprimeBilleeRcm_HelloWorld_HPP

#include "Components/HelloWorld/HelloWorldComponentAc.hpp"

namespace FprimeBilleeRcm {

class HelloWorld final : public HelloWorldComponentBase {
  public:
    // ----------------------------------------------------------------------
    // Component construction and destruction
    // ----------------------------------------------------------------------

    //! Construct HelloWorld object
    HelloWorld(const char* const compName  //!< The component name
    );

    //! Destroy HelloWorld object
    ~HelloWorld();

  private:
    // ----------------------------------------------------------------------
    // Handler implementations for commands
    // ----------------------------------------------------------------------

    //! Handler implementation for command TODO
    //!
    //! TODO
    void TODO_cmdHandler(FwOpcodeType opCode,  //!< The opcode
                         U32 cmdSeq            //!< The command sequence number
                         ) override;
};

}  // namespace FprimeBilleeRcm

#endif
