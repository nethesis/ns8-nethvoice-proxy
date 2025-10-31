-- Create table to map trunk source IP:port to slot names (Kamailio htable format)
CREATE TABLE public.trunk_slot_mappings (
    id SERIAL PRIMARY KEY,
    key_name VARCHAR(64) NOT NULL DEFAULT '',
    key_type INTEGER NOT NULL DEFAULT 0,
    value_type INTEGER NOT NULL DEFAULT 0,
    key_value VARCHAR(128) NOT NULL DEFAULT '',
    expires INTEGER NOT NULL DEFAULT 0
);

-- Create index on key_name for faster lookups
CREATE INDEX trunk_slot_mappings_key_name_idx ON public.trunk_slot_mappings (key_name);

-- Add comment for documentation
COMMENT ON TABLE public.trunk_slot_mappings IS
    'Maps trunk source IP:port to named socket slots for providers like Vianova that require unique IP:port combinations. Uses Kamailio htable format.';

COMMENT ON COLUMN public.trunk_slot_mappings.key_name IS
    'Source IP:port of the trunk (e.g., 192.168.1.10:5060).';

COMMENT ON COLUMN public.trunk_slot_mappings.key_value IS
    'Named socket slot for outbound traffic (e.g., slot1, slot2).';

