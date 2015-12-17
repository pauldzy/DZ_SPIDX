# DZ_SPIDX
PL/SQL utilities for the manipulation of Oracle Spatial indexes including persistence of spatial index parameters.
For the most up-to-date documentation see the auto-build  [dz_spidx_deploy.pdf](https://github.com/pauldzy/DZ_SPIDX/blob/master/dz_spidx_deploy.pdf).

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

## Installation
Simply execute the deployment script into the schema of your choice.  Then execute the code using either the same or a different schema.  All procedures and functions are publically executable and utilize AUTHID CURRENT_USER for permissions handling.
