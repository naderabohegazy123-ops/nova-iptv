-- NOVA IPTV: paid lifetime licenses, one active device per license.
-- Review the existing table definitions before applying this migration.
create or replace function public.activate_license_device(
  p_license_key_hash text,
  p_device_id_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_license public.licenses%rowtype;
  v_device public.license_devices%rowtype;
  v_active_count integer;
begin
  select * into v_license
  from public.licenses
  where license_key_hash = p_license_key_hash
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'مفتاح الترخيص غير صحيح');
  end if;

  if v_license.status <> 'active'
     or v_license.license_type <> 'lifetime'
     or (v_license.expires_at is not null and v_license.expires_at <= now()) then
    return jsonb_build_object('success', false, 'error', 'الترخيص غير نشط أو غير صالح');
  end if;

  select * into v_device
  from public.license_devices
  where license_id = v_license.id
    and device_id_hash = p_device_id_hash
  order by activated_at desc
  limit 1;

  if found and v_device.deactivated_at is null then
    update public.license_devices
      set last_validated_at = now()
      where id = v_device.id;
    return jsonb_build_object('success', true, 'activated', true, 'entitled', true);
  end if;

  select count(*) into v_active_count
  from public.license_devices
  where license_id = v_license.id
    and deactivated_at is null;

  if v_active_count >= coalesce(v_license.max_devices, 1) then
    return jsonb_build_object('success', false, 'error', 'تم استخدام هذا المفتاح على جهاز آخر');
  end if;

  insert into public.license_devices
    (license_id, device_id_hash, activated_at, last_validated_at, deactivated_at)
  values
    (v_license.id, p_device_id_hash, now(), now(), null);

  return jsonb_build_object('success', true, 'activated', true, 'entitled', true);
end;
$$;

revoke all on function public.activate_license_device(text, text) from public, anon, authenticated;
grant execute on function public.activate_license_device(text, text) to service_role;
