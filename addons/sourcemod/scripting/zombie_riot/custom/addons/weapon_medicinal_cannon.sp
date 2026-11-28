#pragma semicolon 1
#pragma newdecls required

static Handle h_Timer_Medicinal_Cannon_Management[MAXPLAYERS] = {null, ...};

static int Medicinal_Cannon_WeaponID[MAXPLAYERS];

/*public void Weapon_Medicinal_Cannon_Precache()
{
	
}*/

public void Weapon_Medicinal_Cannon_Enable(int client, int weapon)
{
	if(h_Timer_Medicinal_Cannon_Management[client] != null)
	{
		delete h_Timer_Medicinal_Cannon_Management[client];
		h_Timer_Medicinal_Cannon_Management[client] = null;
		DataPack pack;
		h_Timer_Medicinal_Cannon_Management[client] = CreateDataTimer(0.1, Timer_Management_Medicinal_Cannon, pack, TIMER_REPEAT);
		pack.WriteCell(client);
	}
	else
	{
		DataPack pack;
		h_Timer_Medicinal_Cannon_Management[client] = CreateDataTimer(0.1, Timer_Management_Medicinal_Cannon, pack, TIMER_REPEAT);
		pack.WriteCell(client);
	}
}

public void Weapon_Medicinal_Cannon_Deploy(int client, int weapon)
{
	if(IsValidEntity(weapon))
	{
		fl_Charge_delay[weapon] = 0.0;
		Medicinal_Cannon_WeaponID[client]=EntIndexToEntRef(weapon);
	}
}

public void Weapon_Medicinal_Cannon_Holster(int client)
{
	Medicinal_Cannon_WeaponID[client]=-1;
}

static Action Timer_Management_Medicinal_Cannon(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int weapon = EntRefToEntIndex(Medicinal_Cannon_WeaponID[client]);
	if(!IsValidClient(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsValidEntity(weapon))
	{
		h_Timer_Medicinal_Cannon_Management[client] = null;
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public void Weapon_Medicinal_Cannon_M1(int client, int weapon, bool crit, int slot)
{
	float RocketDMG=125.0;
	float RocketSpeed=800.0;
	float RocketRadius=EXPLOSION_RADIUS;
	
	RocketSpeed*=Attributes_GetOnWeapon(client, weapon, 103);
	RocketDMG*=Attributes_GetOnWeapon(client, weapon, 8);
	RocketRadius*=Attributes_GetOnWeapon(client, weapon, 99);
	
	float vecAngles[3], fVel[3];
	GetClientEyeAngles(client, vecAngles);
	
	vecAngles[0] -= 40.0;
	if(vecAngles[0] < -89.0)
		vecAngles[0] = -89.0;
	int Projectile=Wand_Projectile_Spawn(client, RocketSpeed, 5000.0/RocketSpeed, RocketDMG, 0, weapon, "rockettrail_RocketJumper");
	GetAngleVectors(vecAngles, fVel, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(fVel, RocketSpeed);
	TeleportEntity(Projectile, NULL_VECTOR, NULL_VECTOR, fVel);
	
	Better_Gravity_Rocket(Projectile, 55.0);
	WandProjectile_ApplyFunctionToEntity(Projectile, MedicinalBombTouch);
	fl_Charge_Duration[Projectile]=RocketRadius;
	fl_Dead_Ringer_Invis[Projectile]=Attributes_GetOnWeapon(client, weapon, Attrib_AddUberChargeOnHeal, true);
	Projectile=ApplyCustomModelToWandProjectile(Projectile, "models/workshop/weapons/c_models/c_quadball/w_quadball_grenade.mdl", 1.33, "");
	if(ZR_Get_Modifier() == 2)
		SetEntityRenderColor(Projectile, 0, 0, 255, 255);
	else
		SetEntityRenderColor(Projectile, 30, 255, 0, 255);
}

static void MedicinalBombTouch(int entity, int target)
{
	int particle = EntRefToEntIndex(i_WandParticle[entity]);
	int owner = EntRefToEntIndex(i_WandOwner[entity]);
	int weapon = EntRefToEntIndex(i_WandWeapon[entity]);
	float ProjectilePos[3];GetAbsOrigin(entity, ProjectilePos);
	makeexplosion(entity, ProjectilePos, 0, 0);
	ArrayList HitEntitiesSphereExplosionTrace = new ArrayList();
	DoAllysExlosionTraceCheck(ProjectilePos, fl_Charge_Duration[entity], owner, HitEntitiesSphereExplosionTrace);
	int length = HitEntitiesSphereExplosionTrace.Length;
	if(length > 0)
	{
		static float distance[MAXENTITIES];
		static float VicPos[MAXENTITIES][3];
		for(int i = length - 1; i >= 0; i--)
		{
			int entity_traced = HitEntitiesSphereExplosionTrace.Get(i);
			
			WorldSpaceCenter(entity_traced, VicPos[entity_traced]);
			distance[entity_traced] = GetVectorDistance(VicPos[entity_traced], ProjectilePos, true);
			if(distance[entity_traced] > (fl_Charge_Duration[entity] * fl_Charge_Duration[entity]) || owner==entity_traced)
			{
				HitEntitiesSphereExplosionTrace.Erase(i);
				continue;
			}
		}
	}
	float damage_reduction = 1.0;
	length = HitEntitiesSphereExplosionTrace.Length;
	if(length > 0)
	{
		for(int repeatloop = 0; repeatloop < 12 && length > 0; repeatloop++)
		{
			float ClosestLowHp;
			int LowHpIndex;
			for(int i = 0; i < length; i++)
			{
				int entity_traced = HitEntitiesSphereExplosionTrace.Get(i);
				float HPer = float(GetEntProp(entity_traced, Prop_Data, "m_iHealth"))/float(ReturnEntityMaxHealth(entity_traced));
				if(ClosestLowHp)
				{
					if(HPer < ClosestLowHp) 
					{
						LowHpIndex = i;
						ClosestLowHp = HPer;  
					}
				}
				else
				{
					LowHpIndex = i;
					ClosestLowHp = HPer;
				}
			}
			int LowHPTarget = HitEntitiesSphereExplosionTrace.Get(LowHpIndex);
			HitEntitiesSphereExplosionTrace.Erase(LowHpIndex);
			length--;
			
			if(IsValidEntity(LowHPTarget))
			{
				static float TotalHeal;
				TotalHeal = f_WandDamage[entity];
				TotalHeal *= 0.5;
				TotalHeal *= damage_reduction;
				
				HealEntityGlobal(owner, LowHPTarget, TotalHeal, 1.0, 0.0, .AddUberCharge = fl_Dead_Ringer_Invis[entity]);	
				
				damage_reduction *= EXPLOSION_AOE_DAMAGE_FALLOFF;
			}
		}
	}
	delete HitEntitiesSphereExplosionTrace;
	
	Explode_Logic_Custom(f_WandDamage[entity], owner, owner, weapon, ProjectilePos, fl_Charge_Duration[entity], Attributes_Get(weapon, 117, 1.0)/*, _, _, _, _, _, IM_ON_FIREEEEE*/);
	if(IsValidEntity(particle))
		RemoveEntity(particle);
	RemoveEntity(entity);
}

/*static void IM_ON_FIREEEEE(int entity, int victim, float damage, int weapon)
{
	NPC_Ignite(victim, entity, 3.0, weapon);
}*/

static void DoAllysExlosionTraceCheck(const float pos1[3], float radius, int entity, ArrayList HitEntitiesSphereExplosionTrace)
{
	DataPack packFilter = new DataPack();
	packFilter.WriteCell(HitEntitiesSphereExplosionTrace);
	packFilter.WriteCell(entity);
	TR_EnumerateEntitiesSphere(pos1, radius, PARTITION_NON_STATIC_EDICTS, TraceEntityAllyInRange, packFilter);

	delete packFilter;
}

static bool TraceEntityAllyInRange(int entity, DataPack packFilter)
{
	packFilter.Reset();
	ArrayList HitEntitiesSphereExplosionTrace = packFilter.ReadCell();
	int filterentity = packFilter.ReadCell();
	if(IsValidAlly(filterentity, entity))
		HitEntitiesSphereExplosionTrace.Push(entity);
	return true;
}