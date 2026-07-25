// Embedded RP2350 sizing for the parameter database. This deployment currently
// defines no parameters, but keeps spare entries so parameters can be added.
#ifndef PRMDB_PRMDBLIMPLCFG_HPP_
#define PRMDB_PRMDBLIMPLCFG_HPP_

namespace {

enum {
    PRMDB_NUM_DB_ENTRIES = 8,
    PRMDB_ENTRY_DELIMITER = 0xA5
};

}

#endif  // PRMDB_PRMDBLIMPLCFG_HPP_
