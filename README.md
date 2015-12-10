# DZ_SPIDX
PL/SQL utilities for the manipulation of Oracle Spatial indexes including persistence of spatial index parameters.

Sample usage:
``` sql
DECLARE
   ary_indexes dz_spidx_list;

BEGIN

   -- Drop any existing spatial indexes, details are captured in the type object
   ary_indexes := dz_spidx_main.flush_spatial_indexes(
       p_owner      => 'RAD_PUBLIC'
      ,p_table_name => 'RAD_IMPWTMDLS_A'
   );
   
   -- Refresh the materialized view
   DBMS_MVIEW.REFRESH(
      list           => 'RAD_PUBLIC.RAD_IMPWTMDLS_A',
      method         => 'C',
      atomic_refresh => FALSE
   );
   
   -- Recreate the spatial indexes
   dz_spidx_main.recreate_spatial_indexes(ary_indexes);
   
END;
/
```
