module rp2040Deployment {

  enum Ports_RateGroups {
    rateGroup1
  }

  topology rp2040Deployment {
    import CdhCore.Subtopology
    import ComFprime.Subtopology

    instance chronoTime
    instance rateGroup1
    instance rateGroupDriver
    instance timer
    instance comDriver

    command connections instance CdhCore.cmdDisp
    event connections instance CdhCore.events
    telemetry connections instance CdhCore.tlmSend
    text event connections instance CdhCore.textLogger
    health connections instance CdhCore.$health
    time connections instance chronoTime

    connections ComFprime_CdhCore {
      CdhCore.events.PktSend -> ComFprime.comQueue.comPacketQueueIn[ComFprime.Ports_ComPacketQueue.EVENTS]
      CdhCore.tlmSend.PktSend -> ComFprime.comQueue.comPacketQueueIn[ComFprime.Ports_ComPacketQueue.TELEMETRY]

      ComFprime.fprimeRouter.commandOut -> CdhCore.cmdDisp.seqCmdBuff
      CdhCore.cmdDisp.seqCmdStatus -> ComFprime.fprimeRouter.cmdResponseIn
    }

    connections Communications {
      comDriver.allocate -> ComFprime.commsBufferManager.bufferGetCallee
      comDriver.deallocate -> ComFprime.commsBufferManager.bufferSendIn

      comDriver.$recv -> ComFprime.comStub.drvReceiveIn
      ComFprime.comStub.drvReceiveReturnOut -> comDriver.recvReturnIn

      ComFprime.comStub.drvSendOut -> comDriver.$send
      comDriver.ready -> ComFprime.comStub.drvConnected
    }

    connections RateGroups {
      timer.CycleOut -> rateGroupDriver.CycleIn

      rateGroupDriver.CycleOut[Ports_RateGroups.rateGroup1] -> rateGroup1.CycleIn
      rateGroup1.RateGroupMemberOut[0] -> CdhCore.tlmSend.Run
      rateGroup1.RateGroupMemberOut[1] -> CdhCore.$health.Run
      rateGroup1.RateGroupMemberOut[2] -> ComFprime.comQueue.run
      rateGroup1.RateGroupMemberOut[3] -> comDriver.schedIn
    }

    connections rp2040Deployment {

    }
  }
}
