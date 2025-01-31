import { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { Modal } from '../ui/modal';
import { PropertyDetails } from '../properties/property-details';
import { Building2, Phone, Mail, MapPin, Calendar } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { motion } from 'framer-motion';
import { formatPhoneNumber } from '@/lib/utils';
import { withDataChangeMutex } from '@/lib/data-change-mutex';
import { handleError } from '@/lib/error-handler';

interface ContactDetailsProps {
  contactId: string;
  isOpen: boolean;
  onClose: () => void;
}

interface Property {
  id: string;
  address: string;
  lead_status: string;
  relationship_type: string;
}

interface ContactDetails {
  id: string;
  first_name: string;
  last_name: string;
  business_name?: string;
  email: string;
  phone_numbers: {
    number: string;
    type: string;
    is_primary: boolean;
  }[];
  properties: Property[];
  notes?: string;
  created_at: string;
  updated_at: string;
}

export function ContactDetails({ contactId, isOpen, onClose }: ContactDetailsProps) {
  const [contact, setContact] = useState<ContactDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedProperty, setSelectedProperty] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen && contactId) {
      loadContactDetails();
    }
  }, [contactId, isOpen]);

  const loadContactDetails = async () => {
    try {
      // Use data change mutex to prevent duplicate calls
      const result = await withDataChangeMutex(
        'contacts',
        { contactId, isOpen },
        async () => {
          const { data, error } = await supabase
            .from('contacts')
            .select(`
              *,
              phone_numbers (
                number,
                type,
                is_primary
              ),
              property_contact_relations (
                relationship_type,
                property:properties (
                  id,
                  address,
                  lead_status
                )
              )
            `)
            .eq('id', contactId)
            .single();

          if (error) {
            throw handleError(error, {
              file: 'contact-details.tsx',
              function: 'loadContactDetails',
              operation: 'fetch contact details'
            });
          }

          // Transform the data
          return {
            ...data,
            phone_numbers: data.phone_numbers || [],
            properties: data.property_contact_relations?.map((rel: any) => ({
              id: rel.property.id,
              address: rel.property.address,
              lead_status: rel.property.lead_status,
              relationship_type: rel.relationship_type
            })) || []
          };
        }
      );

      // Only update state if we got new data
      if (result !== null) {
        setContact(result);
      }
    } catch (error) {
      console.error('Error loading contact details:', error);
    } finally {
      setLoading(false);
    }
  };

  if (!contact) return null;

  return (
    <>
      <Modal
        isOpen={isOpen}
        onClose={onClose}
        title="Contact Details"
        className="max-w-3xl"
      >
        {loading ? (
          <div className="flex justify-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-brand-600" />
          </div>
        ) : (
          <div className="space-y-6">
            {/* Basic Information */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3 }}
            >
              <div className="flex items-center gap-4">
                <div className="h-16 w-16 rounded-full bg-brand-100 flex items-center justify-center">
                  <span className="text-2xl font-semibold text-brand-600">
                    {contact.first_name[0]}{contact.last_name[0]}
                  </span>
                </div>
                <div>
                  <h3 className="text-xl font-semibold">
                    {contact.first_name} {contact.last_name}
                  </h3>
                  {contact.business_name && (
                    <p className="text-sm text-gray-500">
                      {contact.business_name}
                    </p>
                  )}
                </div>
              </div>
            </motion.div>

            {/* Contact Information */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, delay: 0.1 }}
              className="grid grid-cols-2 gap-6"
            >
              <div>
                <h4 className="text-sm font-medium text-gray-500 mb-2">Contact Details</h4>
                <div className="space-y-3">
                  <p className="flex items-center text-gray-600">
                    <Mail className="w-4 h-4 mr-2" />
                    {contact.email}
                  </p>
                  {contact.phone_numbers.map((phone, index) => (
                    <p key={index} className="flex items-center text-gray-600">
                      <Phone className="w-4 h-4 mr-2" />
                      {formatPhoneNumber(phone.number)}
                      <span className="ml-2 px-2 py-0.5 rounded-full text-xs bg-gray-100">
                        {phone.type}
                      </span>
                      {phone.is_primary && (
                        <span className="ml-2 px-2 py-0.5 rounded-full text-xs bg-brand-100 text-brand-800">
                          Primary
                        </span>
                      )}
                    </p>
                  ))}
                </div>
              </div>
              <div>
                <h4 className="text-sm font-medium text-gray-500 mb-2">Account Info</h4>
                <div className="space-y-3">
                  <p className="flex items-center text-gray-600">
                    <Calendar className="w-4 h-4 mr-2" />
                    Created {formatDistanceToNow(new Date(contact.created_at), { addSuffix: true })}
                  </p>
                  <p className="flex items-center text-gray-600">
                    <Building2 className="w-4 h-4 mr-2" />
                    {contact.properties.length} associated properties
                  </p>
                </div>
              </div>
            </motion.div>

            {/* Properties */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, delay: 0.2 }}
            >
              <h4 className="text-sm font-medium text-gray-500 mb-4">Associated Properties</h4>
              <div className="space-y-4">
                {contact.properties.map((property) => (
                  <div
                    key={property.id}
                    className="bg-gray-50 p-4 rounded-lg hover:bg-gray-100 transition-colors cursor-pointer"
                    onClick={() => setSelectedProperty(property.id)}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center">
                        <Building2 className="w-5 h-5 text-gray-400 mr-2" />
                        <span className="font-medium">{property.address}</span>
                      </div>
                      <div className="flex items-center gap-2">
                        {property.lead_status && (
                          <span className={`px-2 py-1 rounded text-xs font-medium ${
                            property.lead_status === 'interested'
                              ? 'bg-green-100 text-green-800'
                              : property.lead_status === 'not_interested'
                              ? 'bg-gray-100 text-gray-800'
                              : 'bg-red-100 text-red-800'
                          }`}>
                            {property.lead_status.replace('_', ' ').charAt(0).toUpperCase() + 
                             property.lead_status.replace('_', ' ').slice(1)}
                          </span>
                        )}
                        <span className="text-xs bg-brand-100 text-brand-800 px-2 py-1 rounded">
                          {property.relationship_type.replace('_', ' ')}
                        </span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </motion.div>

            {/* Notes */}
            {contact.notes && (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.3, delay: 0.3 }}
              >
                <h4 className="text-sm font-medium text-gray-500 mb-2">Notes</h4>
                <p className="text-gray-600 whitespace-pre-wrap">{contact.notes}</p>
              </motion.div>
            )}
          </div>
        )}
      </Modal>

      {/* Property Details Modal */}
      {selectedProperty && (
        <PropertyDetails
          propertyId={selectedProperty}
          isOpen={true}
          onClose={() => setSelectedProperty(null)}
        />
      )}
    </>
  );
}